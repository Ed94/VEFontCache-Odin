package vefontcache

/* Note(Ed):
	Original implementation has been changed moderately.
	Notably the LRU is now type generic for its key value.
	This was done to profile between using u64, u32, and u16.

	What ended up happening was using u32 for both the atlas and the shape cache 
	yielded a several ms save for processing thousands of draw text calls.

	There was an attempt at an optimization pass but the directives done here (other than force_inline)
	are marginal changes at best.
*/

// 16-bit hashing was attempted, however it seems to get collisions with djb8_hash_16

LRU_Fail_Mask_16 :: 0xFFFF
LRU_Fail_Mask_32 :: 0xFFFFFFFF
LRU_Fail_Mask_64 :: 0xFFFFFFFFFFFFFFFF

Pool_ListIter  :: i32

Pool_List_Item :: struct( $V_Type : typeid ) #packed {
// Pool_List_Item :: struct( $V_Type : typeid ) {
	prev  : Pool_ListIter,
	next  : Pool_ListIter,
	value : V_Type,
}

Pool_List :: struct( $V_Type : typeid) {
	items     : [dynamic]Pool_List_Item(V_Type),
	free_list : [dynamic]Pool_ListIter,
	front     : Pool_ListIter,
	back      : Pool_ListIter,
	size      : i32,
	capacity  : i32,
	dbg_name  : string,
}

pool_list_init :: proc( pool : ^Pool_List($V_Type), capacity : i32, dbg_name : string = "" )
{
	error : Allocator_Error
	pool.items, error = make( [dynamic]Pool_List_Item(V_Type), int(capacity) )
	assert( error == .None, "VEFontCache.pool_list_inits: Failed to allocate items array")
	resize( & pool.items, capacity )

	pool.free_list, error = make( [dynamic]Pool_ListIter, len = 0, cap = int(capacity) )
	assert( error == .None, "VEFontCache.pool_list_init: Failed to allocate free_list array")
	resize( & pool.free_list, capacity )

	pool.capacity = capacity

	pool.dbg_name = dbg_name

	for id in 0 ..< pool.capacity {
		pool.free_list[id] = Pool_ListIter(id)
		pool.items[id] = {
			prev = -1,
			next = -1,
		}
	}

	pool.front = -1
	pool.back  = -1
}

pool_list_free :: proc( pool : ^Pool_List($V_Type) ) {
	delete( pool.items)
	delete( pool.free_list)
}

pool_list_reload :: proc( pool : ^Pool_List($V_Type), allocator : Allocator ) {
	reload_array( & pool.items, allocator )
	reload_array( & pool.free_list, allocator )
}

pool_list_clear :: proc( pool: ^Pool_List($V_Type) )
{
	clear(& pool.items)
	clear(& pool.free_list)
	resize( & pool.items, cap(pool.items) )
	resize( & pool.free_list, cap(pool.free_list) )

	for id in 0 ..< pool.capacity {
		pool.free_list[id] = Pool_ListIter(id)
		pool.items[id] = {
			prev = -1,
			next = -1,
		}
	}

	pool.front = -1
	pool.back  = -1
	pool.size  = 0
}

@(optimization_mode="size")
pool_list_push_front :: proc( pool : ^Pool_List($V_Type), value : V_Type ) #no_bounds_check
{
	if pool.size >= pool.capacity do return

	length := len(pool.free_list)
	assert( length > 0 )
	assert( length == int(pool.capacity - pool.size) )

	id := pool.free_list[ len(pool.free_list) - 1 ]
	// if pool.dbg_name != "" {
	// 	logf("pool_list: back %v", id)
	// }
	pop( & pool.free_list )
	pool.items[ id ].prev  = -1
	pool.items[ id ].next  = pool.front
	pool.items[ id ].value = value
	// if pool.dbg_name != "" {
	// 	logf("pool_list: pushed %v into id %v", value, id)
	// }

	if pool.front != -1 do pool.items[ pool.front ].prev = id
	if pool.back  == -1 do pool.back = id
	pool.front  = id
	pool.size  += 1
}

@(optimization_mode="size")
pool_list_erase :: proc( pool : ^Pool_List($V_Type), iter : Pool_ListIter ) #no_bounds_check
{
	if pool.size <= 0 do return
	assert( iter >= 0 && iter < Pool_ListIter(pool.capacity) )
	assert( len(pool.free_list) == int(pool.capacity - pool.size) )

	iter_node := & pool.items[ iter ]
	prev := iter_node.prev
	next := iter_node.next

	if iter_node.prev != -1 do pool.items[ prev ].next = iter_node.next
	if iter_node.next != -1 do pool.items[ next ].prev = iter_node.prev

	if pool.front == iter do pool.front = iter_node.next
	if pool.back  == iter do pool.back  = iter_node.prev

	iter_node.prev  = -1
	iter_node.next  = -1
	iter_node.value = 0
	append( & pool.free_list, iter )

	pool.size -= 1
	if pool.size == 0 {
		pool.back  = -1
		pool.front = -1
	}
}

@(optimization_mode="size")
pool_list_move_to_front :: proc "contextless" ( pool : ^Pool_List($V_Type), iter : Pool_ListIter ) #no_bounds_check
{
	if pool.front == iter do return

	item := & pool.items[iter]
	if item.prev != -1   do pool.items[ item.prev ].next = item.next
	if item.next != -1   do pool.items[ item.next ].prev = item.prev
	if pool.back == iter do pool.back = item.prev

	item.prev                     = -1
	item.next                     = pool.front
	pool.items[ pool.front ].prev = iter
	pool.front                    = iter
}

@(optimization_mode="size")
pool_list_peek_back :: #force_inline proc ( pool : Pool_List($V_Type) ) -> V_Type #no_bounds_check {
	assert( pool.back != - 1 )
	value := pool.items[ pool.back ].value
	return value
}

@(optimization_mode="size")
pool_list_pop_back :: #force_inline proc( pool : ^Pool_List($V_Type) ) -> V_Type #no_bounds_check { 
	if pool.size <= 0 do return 0
	assert( pool.back != -1 )

	value := pool.items[ pool.back ].value
	pool_list_erase( pool, pool.back )
	return value
}

LRU_Link :: struct #packed {
	value : i32,
	ptr   : Pool_ListIter,
}

LRU_Cache :: struct( $Key_Type : typeid ) {
	capacity  : i32,
	num       : i32,
	table     :  map[Key_Type]LRU_Link,
	key_queue : Pool_List(Key_Type),
}

lru_init :: proc( cache : ^LRU_Cache($Key_Type), capacity : i32, dbg_name : string = "" ) {
	error : Allocator_Error
	cache.capacity     = capacity
	cache.table, error = make( map[Key_Type]LRU_Link, uint(capacity) )
	assert( error == .None, "VEFontCache.lru_init : Failed to allocate cache's table")

	pool_list_init( & cache.key_queue, capacity, dbg_name = dbg_name )
}	

lru_free :: proc( cache : ^LRU_Cache($Key_Type) ) {
	pool_list_free( & cache.key_queue )
	delete( cache.table )
}

lru_reload :: #force_inline proc( cache : ^LRU_Cache($Key_Type), allocator : Allocator ) {
	reload_map( & cache.table, allocator )
	pool_list_reload( & cache.key_queue, allocator )
}

lru_clear :: proc ( cache : ^LRU_Cache($Key_Type) ) {
	pool_list_clear( & cache.key_queue )
	clear(& cache.table)
	cache.num = 0
}

@(optimization_mode="size")
lru_find :: #force_inline proc "contextless" ( cache : LRU_Cache($Key_Type), key : Key_Type, must_find := false ) -> (LRU_Link, bool) #no_bounds_check { 
	link, success := cache.table[key]
	return link, success
}

@(optimization_mode="size")
lru_get :: #force_inline proc ( cache: ^LRU_Cache($Key_Type), key : Key_Type ) -> i32 #no_bounds_check {
	if link, ok := &cache.table[ key ]; ok {
		pool_list_move_to_front(&cache.key_queue, link.ptr)
		return link.value
	}
	return -1
}

@(optimization_mode="size")
lru_get_next_evicted :: #force_inline proc ( cache : LRU_Cache($Key_Type) ) -> Key_Type #no_bounds_check {
	if cache.key_queue.size >= cache.capacity {
		evict := pool_list_peek_back( cache.key_queue )
		return evict
	}
	return ~Key_Type(0)
}

@(optimization_mode="size")
lru_peek :: #force_inline proc "contextless" ( cache : LRU_Cache($Key_Type), key : Key_Type, must_find := false ) -> i32 #no_bounds_check {
	iter, success := lru_find( cache, key, must_find )
	if success == false {
		return -1
	}
	return iter.value
}

@(optimization_mode="size")
lru_put :: proc( cache : ^LRU_Cache($Key_Type), key : Key_Type, value : i32 ) -> Key_Type #no_bounds_check
{
	// profile(#procedure)
	if link, ok := & cache.table[ key ]; ok {
		pool_list_move_to_front( & cache.key_queue, link.ptr )
		link.value = value
		return key
	}

	evict := key
	if cache.key_queue.size >= cache.capacity {
		evict = pool_list_pop_back(&cache.key_queue)
		delete_key(&cache.table, evict)
		cache.num -= 1
	}

	pool_list_push_front(&cache.key_queue, key)
	cache.table[key] = LRU_Link{
			value = value,
			ptr   = cache.key_queue.front,
	}
	cache.num += 1
	return evict
}

lru_refresh :: proc( cache : ^LRU_Cache($Key_Type), key : Key_Type ) {
	link, success := lru_find( cache ^, key )
	pool_list_erase( & cache.key_queue, link.ptr )
	pool_list_push_front( & cache.key_queue, key )
	link.ptr = cache.key_queue.front
}
