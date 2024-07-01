package VEFontCache

/*
The choice was made to keep the LRU cache implementation as close to the original as possible.
*/

import "base:runtime"

PoolListIter  :: i32
PoolListValue :: u64

PoolListItem :: struct {
	prev  : PoolListIter,
	next  : PoolListIter,
	value : PoolListValue,
}

PoolList :: struct {
	items     : [dynamic]PoolListItem,
	free_list : [dynamic]PoolListIter,
	front     : PoolListIter,
	back      : PoolListIter,
	size      : i32,
	capacity  : i32,
	dbg_name  : string,
}

pool_list_init :: proc( pool : ^PoolList, capacity : i32, dbg_name : string = "" )
{
	error : AllocatorError
	pool.items, error = make( [dynamic]PoolListItem, int(capacity) )
	assert( error == .None, "VEFontCache.pool_list_init : Failed to allocate items array")
	resize( & pool.items, capacity )

	pool.free_list, error = make( [dynamic]PoolListIter, len = 0, cap = int(capacity) )
	assert( error == .None, "VEFontCache.pool_list_init : Failed to allocate free_list array")
	resize( & pool.free_list, capacity )

	pool.capacity = capacity

	pool.dbg_name = dbg_name
	using pool

	for id in 0 ..< capacity {
		free_list[id] = i32(id)
		items[id] = {
			prev = -1,
			next = -1,
		}
	}

	front = -1
	back  = -1
}

pool_list_free :: proc( pool : ^PoolList ) {
	// TODO(Ed): Implement
}

pool_list_reload :: proc( pool : ^PoolList, allocator : Allocator ) {
	reload_array( & pool.items, allocator )
	reload_array( & pool.free_list, allocator )
}

pool_list_push_front :: proc( pool : ^PoolList, value : PoolListValue )
{
	using pool
	if size >= capacity do return

	length := len(free_list)
	assert( length > 0 )
	assert( length == int(capacity - size) )

	id := free_list[ len(free_list) - 1 ]
	if pool.dbg_name != "" {
		logf("pool_list: back %v", id)
	}
	pop( & free_list )
	items[ id ].prev  = -1
	items[ id ].next  = front
	items[ id ].value = value
	if pool.dbg_name != "" {
		logf("pool_list: pushed %v into id %v", value, id)
	}

	if front != -1 do items[ front ].prev = id
	if back  == -1 do back = id
	front  = id
	size  += 1
}

pool_list_erase :: proc( pool : ^PoolList, iter : PoolListIter )
{
	using pool
	if size <= 0 do return
	assert( iter >= 0 && iter < i32(capacity) )
	assert( len(free_list) == int(capacity - size) )

	iter_node := & items[ iter ]
	prev := iter_node.prev
	next := iter_node.next

	if iter_node.prev != -1 do items[ prev ].next = iter_node.next
	if iter_node.next != -1 do items[ next ].prev = iter_node.prev

	if front == iter do front = iter_node.next
	if back  == iter do back  = iter_node.prev

	iter_node.prev  = -1
	iter_node.next  = -1
	iter_node.value = 0
	append( & free_list, iter )

	size -= 1
	if size == 0 {
		back  = -1
		front = -1
	}
}

pool_list_move_to_front :: #force_inline proc( pool : ^PoolList, iter : PoolListIter )
{
	using pool

	if front == iter do return

	item := & items[iter]
	if item.prev != -1   do items[ item.prev ].next = item.next
	if item.next != -1   do items[ item.next ].prev = item.prev
	if back      == iter do back = item.prev

	item.prev           = -1
	item.next           = front
	items[ front ].prev = iter
	front               = iter
}

pool_list_peek_back :: #force_inline proc ( pool : ^PoolList ) -> PoolListValue {
	assert( pool.back != - 1 )
	value := pool.items[ pool.back ].value
	return value
}

pool_list_pop_back :: #force_inline proc( pool : ^PoolList ) -> PoolListValue {
	if pool.size <= 0 do return 0
	assert( pool.back != -1 )

	value := pool.items[ pool.back ].value
	pool_list_erase( pool, pool.back )
	return value
}

LRU_Link :: struct {
	pad_top : u64,
	value : i32,
	ptr   : PoolListIter,
	pad_bottom : u64,
}

LRU_Cache :: struct {
	capacity  : i32,
	num       : i32,
	table     :  map[u64]LRU_Link,
	key_queue : PoolList,
}

LRU_init :: proc( cache : ^LRU_Cache, capacity : i32, dbg_name : string = "" ) {
	error : AllocatorError
	cache.capacity     = capacity
	cache.table, error = make( map[u64]LRU_Link, uint(capacity) )
	assert( error == .None, "VEFontCache.LRU_init : Failed to allocate cache's table")

	pool_list_init( & cache.key_queue, capacity, dbg_name = dbg_name )
}

LRU_free :: proc( cache : ^LRU_Cache ) {
	// TODO(Ed): Implement
}

LRU_reload :: #force_inline proc( cache : ^LRU_Cache, allocator : Allocator ) {
	reload_map( & cache.table, allocator )
	pool_list_reload( & cache.key_queue, allocator )
}

LRU_find :: #force_inline proc "contextless" ( cache : ^LRU_Cache, key : u64, must_find := false ) -> (LRU_Link, bool) {
	link, success := cache.table[key]
	return link, success
}

LRU_get :: #force_inline proc( cache: ^LRU_Cache, key : u64 ) -> i32 {
	if link, ok := &cache.table[ key ]; ok {
			pool_list_move_to_front(&cache.key_queue, link.ptr)
			return link.value
	}
	return -1
}

LRU_get_next_evicted :: #force_inline proc ( cache : ^LRU_Cache ) -> u64 {
	if cache.key_queue.size >= cache.capacity {
		evict := pool_list_peek_back( & cache.key_queue )
		return evict
	}
	return 0xFFFFFFFFFFFFFFFF
}

LRU_peek :: #force_inline proc ( cache : ^LRU_Cache, key : u64, must_find := false ) -> i32 {
	iter, success := LRU_find( cache, key, must_find )
	if success == false {
		return -1
	}
	return iter.value
}

LRU_put :: #force_inline proc( cache : ^LRU_Cache, key : u64, value : i32 ) -> u64
{
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

LRU_refresh :: proc( cache : ^LRU_Cache, key : u64 ) {
	link, success := LRU_find( cache, key )
	pool_list_erase( & cache.key_queue, link.ptr )
	pool_list_push_front( & cache.key_queue, key )
	link.ptr = cache.key_queue.front
}
