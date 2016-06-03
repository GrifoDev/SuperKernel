/* linux/arch/arm64/mach-exynos/include/mach/asv.h
 *
 * copyright (c) 2014 samsung electronics co., ltd.
 *              http://www.samsung.com/
 *
 * EXYNOS - Adaptive Support Voltage Source File
 *
 * this program is free software; you can redistribute it and/or modify
 * it under the terms of the gnu general public license version 2 as
 * published by the free software foundation.
*/

#ifndef __ASM_ARCH_ASV_CAL_H
#define __ASM_ARCH_ASV_CAL_H __FILE__

enum dvfs_id {
	cal_asv_dvfs_big,
	cal_asv_dvfs_little,
	cal_asv_dvfs_g3d,
	cal_asv_dvfs_mif,
	cal_asv_dvfs_int,
	cal_asv_dvfs_cam,
	cal_asv_dvfs_disp,
	cal_asv_dvs_g3dm,
	num_of_dvfs,
};

enum asv_group {
	asv_max_lv,
	dvfs_freq,
	dvfs_voltage,
	dvfs_rcc,
	dvfs_group,
	table_group,
	ids_group,
	num_of_asc,
};

extern int asv_get_information(enum dvfs_id id,
	enum asv_group grp, unsigned int lv);

#endif /* __ASM_ARCH_ASV_CAL_H */
