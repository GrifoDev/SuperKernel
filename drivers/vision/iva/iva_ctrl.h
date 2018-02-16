/*
 * Copyright (C) 2016 Samsung Electronics Co.Ltd
 *
 * This program is free software; you can redistribute	it and/or modify it
 * under  the terms of	the GNU General  Public License as published by the
 * Free Software Foundation;  either version 2 of the  License, or (at your
 * option) any later version.
 */
#ifndef _IVA_CTRL_H_
#define _IVA_CTRL_H_

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/miscdevice.h>
#include <linux/ion.h>
#include <linux/dma-buf.h>
#include <linux/clk.h>
#include <linux/pm_qos.h>
#include <linux/hashtable.h>
#ifdef CONFIG_PM_SLEEP
#include <linux/wakelock.h>
#endif

/* in case that threaded irq is not supported */
//#define ENABLE_IPCQ_WORK_QUEUE
/* TO DO: move to private */
struct mcu_print_info {
	struct device		*dev;
	unsigned long		delay_jiffies;
	struct delayed_work	dwork;
	struct buf_pos __iomem	*log_pos;
	int		log_buf_size;
	char __iomem	*log_buf;
	int		ch_pos;
};

struct mcu_binary {
#define MCU_BIN_MALLOC		(0x1)
#define MCU_BIN_ION		(0x2)
#define MCU_BIN_ION_CACHE	(0x4)
	uint32_t	flag;
#define IVA_CTRL_BOOT_FILE_LEN	(256)
	char		file[IVA_CTRL_BOOT_FILE_LEN];
	uint32_t	file_size;
	uint32_t	bin_size;
	void		*bin;
	/* ion case */
	struct ion_handle	*handle;
	struct dma_buf		*dmabuf;
	struct dma_buf_attachment *attachment;
	dma_addr_t		io_va;
};


#ifdef ENABLE_IPCQ_WORK_QUEUE
struct iva_ipcq_work {
	struct work_struct	work;
	uint32_t		msg;
};
#endif

struct iva_ipcq_stat {
	struct mutex		trans_mtx;
	struct list_head	trans_head;
	uint32_t		trans_nr_max;
	uint32_t		trans_nr;
};

struct iq_pend_mail;
struct iva_ipcq {
	struct iva_dev_data	*iva_data;
	struct ipc_cmd_queue	*cmd_q;
	struct ipc_res_queue	*res_q;
	struct mutex		ipcq_mutex;
	uint32_t 		ipcq_next_slot;
	uint32_t		req_id;
	bool			ipcq_ctrl_req;
	spinlock_t		ipcq_slock;
	wait_queue_head_t	ipcq_wait_queue;
	unsigned long		wait_to_jiffies;	/* wait time out */
	struct timer_list	to_timer;		/* timeout */
	unsigned int		to_in_ms;
#ifdef ENABLE_IPCQ_WORK_QUEUE
	struct iva_ipcq_work	ipcq_work;
#endif
	struct list_head	ipcq_pend_list;
	spinlock_t		rsv_slock;
	uint32_t		rsv_hint;
	struct iq_pend_mail	*rsv;
	struct iva_ipcq_stat	ipcq_stat;
};


#define IVA_ST_OPENED		(0x1)
#define IVA_ST_INIT_DONE	(0x2)
#define IVA_ST_MCU_BOOT_DONE	(0x3)
#define IVA_ST_PM_QOS_CAM	(0x4)

/* per process information */
struct iva_proc {
	struct list_head	proc_node;
	struct task_struct	*tsk;
	pid_t			pid;
	pid_t			tid;
	struct iva_dev_data	*iva_data;
	unsigned long		state;
	struct mutex		proc_mem_lock;  /* memory lock per process */
	DECLARE_HASHTABLE(h_mem_map, 9);	/* 512 */
};

struct iva_dev_data {
#define IVA_CTL_ALLOC_LOCALLY_F	(0x1)
	uint32_t		flags;
	unsigned long		state;
	struct miscdevice	misc;
	struct device		*dev;
	struct clk *		iva_clk;
#ifdef CONFIG_SOC_EXYNOS8895
	struct pm_qos_request	iva_qos_cam;
	struct pm_qos_request	iva_qos_mif;
#endif
	struct resource		*iva_res;
	void __iomem		*iva_va;

#ifdef CONFIG_PM_SLEEP
	/* maintain to be awake */
	struct wake_lock	iva_wake_lock;
#endif
	/* debug */
	struct notifier_block	k_panic_nb;

	/* per-process */
	struct mutex		proc_mutex;
	struct list_head	proc_head;
	bool			en_hwa_req;

	/* memory related */
	struct mutex 		mem_map_lock;
	uint32_t		map_nr;
	struct list_head	mem_map_list;	/* global mem list*/
	struct ion_client 	*ion_client;
	struct kmem_cache	*map_node_cache;
#ifndef CONFIG_ION_EXYNOS
	struct ion_device 	*ion_dev;
#endif
	/* mcu */
	struct mcu_binary	*mcu_bin;
	uint32_t		mcu_mem_size;
	uint32_t		mcu_shmem_size;	/* start from top */
	uint32_t		mcu_print_delay;
	struct mcu_print_info	*mcu_print;
	struct work_struct	mcu_rd_work;
#define IVA_MBOX_IRQ_NOT_DEFINED	(-ENXIO)/* means polling mode */
	int		mbox_irq_nr;

	/* will be removed */
	void __iomem	*pmu_va;
	void __iomem	*mbox_va;
	void __iomem	*shmem_va;

	struct delayed_work	mbox_dwork;

	struct iva_ipcq	mcu_ipcq;
};

#endif /* _IVA_CTRL_H_ */
