#!/system/bin/sh

# Busybox 
if [ -e /su/xbin/busybox ]; then
	BB=/su/xbin/busybox;
else if [ -e /sbin/busybox ]; then
	BB=/sbin/busybox;
else
	BB=/system/xbin/busybox;
fi;
fi;

cat << CTAG
{
    name:IO,
    elements:[
	{ SPane:{
		title:"I/O Schedulers",
		description:"Set the active I/O elevator algorithm. The I/O Scheduler decides how to prioritize and handle I/O requests. More info: <a href='http://timos.me/tm/wiki/ioscheduler'>Wiki</a>"
	}},
	{ SSpacer:{
		height:1
	}},
	{ SOptionList:{
		title:"Scheduler",
		description:" ",
		default:$(echo $(/res/synapse/actions/bracket-option /sys/block/sda/queue/scheduler)),
		action:"ioset scheduler",
		values:[
`
			for IOSCHED in \`cat /sys/block/sda/queue/scheduler | $BB sed -e 's/\]//;s/\[//'\`; do
				echo "\"$IOSCHED\",";
			done;
`
		],
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, CANCEL ],
				to:"/sys/block/sda/queue/iosched"
			},
			{
				on:REFRESH,
				do:REFRESH,
				to:"/sys/block/sda/queue/iosched"
			}
		]
	}},
	{ SSpacer:{
		height:1
	}},
	{ SOptionList:{
		title:"Storage scheduler SD card",
		description:" ",
		default:$(cat /sys/block/mmcblk0/queue/scheduler | $BB awk 'NR>1{print $1}' RS=[ FS=]),
		action:"ioset scheduler_ext",
		values:[`while read values; do $BB printf "%s, \n" $values | $BB tr -d '[]'; done < /sys/block/mmcblk0/queue/scheduler`],
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, CANCEL ],
				to:"/sys/block/mmcblk0/queue/iosched"
			},
			{
				on:REFRESH,
				do:REFRESH,
				to:"/sys/block/mmcblk0/queue/iosched"
			}
		]
	}},
	{ SSpacer:{
		height:2
	}},
	{ SSeekBar:{
		title:"Read-Ahead Internal",
		description:" ",
		max:4096,
		min:64,
		unit:" KB",
		step:64,
		default:$(cat /sys/block/sda/queue/read_ahead_kb),
		action:"ioset queue read_ahead_kb"
	}},
	{ SSpacer:{
		height:2
	}},
	{ SSeekBar:{
		title:"Read-Ahead SD Card",
		description:" ",
		max:4096,
		min:64,
		unit:" KB",
		step:64,
		default:$(cat /sys/block/mmcblk0/queue/read_ahead_kb),
		action:"ioset queue_ext read_ahead_kb"
	}},
	{ SSpacer:{
		height:1
	}},
	{ SPane:{
		title:"General I/O Tunables",
		description:"Set the internal storage general tunables."
	}},
	{ SSpacer:{
		height:1
	}},
	{ SOptionList:{
		title:"Add Random",
		description:"Draw entropy from spinning (rotational) storage.\n",
		default:0,
		action:"ioset queue add_random",
		values:{
			0:"Disabled", 1:"Enabled"
		}
	}},
	{ SSpacer:{
		height:2
	}},
	{ SOptionList:{
		title:"IO Stats",
		description:"Maintain I/O statistics for this storage device. Disabling will break I/O monitoring apps but reduce CPU overhead.\n",
		default:0,
		action:"ioset queue iostats",
		values:{
			0:"Disabled", 1:"Enabled"
		}
	}},
	{ SSpacer:{
		height:2
	}},
	{ SOptionList:{
		title:"Rotational",
		description:"Treat device as rotational storage.\n",
		default:0,
		action:"ioset queue rotational",
		values:{
			0:"Disabled", 1:"Enabled"
		}
	}},
	{ SSpacer:{
		height:2
	}},
	{ SOptionList:{
		title:"No Merges",
		description:"Types of merges (prioritization) the scheduler queue for this storage device allows.\n",
		default:0,
		action:"ioset queue nomerges",
		values:{
			0:"All", 1:"Simple Only", 2:"None"
		}
	}},
	{ SSpacer:{
		height:2
	}},
	{ SOptionList:{
		title:"RQ Affinity",
		description:"Try to have scheduler requests complete on the CPU core they were made from.\n",
		default:2,
		action:"ioset queue rq_affinity",
		values:{
			0:"Disabled", 1:"Enabled", 2:"Aggressive"
		}
	}},
	{ SSpacer:{
		height:2
	}},
	{ SSeekBar:{
		title:"NR Requests Internal",
		description:"Maximum number of read (or write) requests that can be queued to the scheduler in the block layer.\n",
		step:16,
		min:16,
		max:2048,
		default:$(cat /sys/block/sda/queue/nr_requests),
		action:"ioset queue nr_requests"
	}},
	{ SSpacer:{
		height:2
	}},
	{ SSeekBar:{
		title:"NR Requests SD Card",
		description:"Maximum number of read (or write) requests that can be queued to the scheduler in the block layer.\n",
		step:16,
		min:16,
		max:2048,
		default:$(cat /sys/block/mmcblk0/queue/nr_requests),
		action:"ioset queue_ext nr_requests"
	}},
	{ SSpacer:{
		height:1
	}},
	{ SOptionList:{
		title:"Software CRC control",
		description:"Enabling software CRCs on the data blocks can be a significant (30%) performance cost. So we allow it to be disabled.",
		default:N,
		action:"generic /sys/module/mmc_core/parameters/use_spi_crc",
		values:{
			N:"Disabled", Y:"Enabled"
		}
	}},
	{ SSpacer:{
		height:1
	}},
	{ SPane:{
		title:"I/O Scheduler Tunables Internal"
	}},
	{ SSpacer:{
		height:1
	}},
	{ STreeDescriptor:{
		path:"/sys/block/sda/queue/iosched",
		generic: {
			directory: {},
			element: {
				SGeneric: { title:"@BASENAME" }
			}
		},
		exclude: [ "weights", "wr_max_time" ]
	}},
	{ SPane:{
		title:"I/O Scheduler Tunables SD Card"
	}},
	{ SSpacer:{
		height:1
	}},
	{ STreeDescriptor:{
		path:"/sys/block/mmcblk0/queue/iosched",
		generic: {
			directory: {},
			element: {
				SGeneric: { title:"@BASENAME" }
			}
		},
		exclude: [ "weights", "wr_max_time" ]
	}},
    ]
}
CTAG
