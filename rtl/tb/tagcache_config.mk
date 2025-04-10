CONF_HPDCACHE_PA_WIDTH=49
CONF_HPDCACHE_WORD_WIDTH=1
CONF_HPDCACHE_SETS=64
CONF_HPDCACHE_WAYS=8
CONF_HPDCACHE_CL_WORDS=512
CONF_HPDCACHE_REQ_WORDS=4
CONF_HPDCACHE_REQ_TRANS_ID_WIDTH=6
CONF_HPDCACHE_REQ_SRC_ID_WIDTH=3
CONF_HPDCACHE_VICTIM_SEL=HPDCACHE_VICTIM_PLRU
CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD=2
CONF_HPDCACHE_DATA_SETS_PER_RAM=$(CONF_HPDCACHE_SETS)
CONF_HPDCACHE_DATA_RAM_WBYTEENABLE=1
CONF_HPDCACHE_ACCESS_WORDS=64
CONF_HPDCACHE_MSHR_SETS=32
CONF_HPDCACHE_MSHR_WAYS=2
CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD=$(CONF_HPDCACHE_MSHR_WAYS)
CONF_HPDCACHE_MSHR_SETS_PER_RAM=$(CONF_HPDCACHE_MSHR_SETS)
CONF_HPDCACHE_MSHR_RAM_WBYTEENABLE=1
CONF_HPDCACHE_MSHR_USE_REGBANK=1
CONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH=1
CONF_HPDCACHE_REFILL_FIFO_DEPTH=2
CONF_HPDCACHE_WBUF_DIR_ENTRIES=8
CONF_HPDCACHE_WBUF_DATA_ENTRIES=4
CONF_HPDCACHE_WBUF_WORDS=2
CONF_HPDCACHE_WBUF_TIMECNT_WIDTH=3
CONF_HPDCACHE_WBUF_SEND_FEEDTHROUGH=0
CONF_HPDCACHE_RTAB_ENTRIES=4
CONF_HPDCACHE_FLUSH_ENTRIES=4
CONF_HPDCACHE_FLUSH_FIFO_DEPTH=2
CONF_HPDCACHE_MEM_ADDR_WIDTH=64
CONF_HPDCACHE_MEM_ID_WIDTH=4
CONF_HPDCACHE_MEM_DATA_WIDTH=512
CONF_HPDCACHE_WT_ENABLE=1
CONF_HPDCACHE_WB_ENABLE=1
CONF_HPDCACHE_LOW_LATENCY=1
