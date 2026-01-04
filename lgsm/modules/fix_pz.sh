#!/bin/bash
# LinuxGSM fix_pz.sh module
# Author: Khalen
# Website: https://linuxgsm.com
# Description: Syncs canonical config for Project Zomboid.
# If user has a server.ini in the LGSM config directory,
# copy it to the game's expected location before server start.

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

# Canonical config paths
# Users can place their config at:
#   lgsm/config-lgsm/pzserver/server.ini (default for all instances)
#   lgsm/config-lgsm/pzserver/{selfname}.ini (instance-specific)
canonicalcfg_instance="${configdirserver}/${selfname}.ini"
canonicalcfg_default="${configdirserver}/server.ini"

# Check instance-specific first, then fall back to default
if [ -f "${canonicalcfg_instance}" ]; then
	canonicalcfg="${canonicalcfg_instance}"
elif [ -f "${canonicalcfg_default}" ]; then
	canonicalcfg="${canonicalcfg_default}"
else
	canonicalcfg=""
fi

# Only sync if a canonical config exists
if [ -n "${canonicalcfg}" ] && [ -f "${canonicalcfg}" ]; then
	# Ensure destination directory exists
	if [ ! -d "${servercfgdir}" ]; then
		mkdir -p "${servercfgdir}"
	fi

	# Always overwrite the destination config
	fixname="canonical config sync"
	fn_fix_msg_start
	cp -f "${canonicalcfg}" "${servercfgfullpath}"
	exitcode=$?
	fn_fix_msg_end

	if [ "${exitcode}" -eq 0 ]; then
		fn_script_log_info "Synced canonical config from ${canonicalcfg} to ${servercfgfullpath}"
	else
		fn_script_log_error "Failed to sync canonical config from ${canonicalcfg} to ${servercfgfullpath}"
	fi
fi
