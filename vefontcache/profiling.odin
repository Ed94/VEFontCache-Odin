package vefontcache

// Add profiling hookup here

// import ""

@(deferred_none = profile_end, disabled = DISABLE_PROFILING)
profile :: #force_inline proc "contextless" ( name : string, loc := #caller_location ) {
}

@(disabled = DISABLE_PROFILING)
profile_begin :: #force_inline proc "contextless" ( name : string, loc := #caller_location ) {
}

@(disabled = DISABLE_PROFILING)
profile_end :: #force_inline proc "contextless" () {
}
