#!/bin/bash
# LinuxGSM fix_pz.sh module
# Author: Khalen
# Website: https://linuxgsm.com
# Description: Syncs canonical config, SandboxVars, and local mods for Project Zomboid.
# - server.ini from LGSM config -> ~/Zomboid/Server/
# - SandboxVars.lua from LGSM config -> ~/Zomboid/Server/
# - mods/ from LGSM config -> ~/Zomboid/mods/

moduleselfname="$(basename "$(readlink -f "${BASH_SOURCE[0]}")")"

# Zomboid mods directory (for local/non-workshop mods)
zomboidmodsdir="${HOME}/Zomboid/mods"

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

# SandboxVars.lua sync
# Users can place their SandboxVars at:
#   lgsm/config-lgsm/pzserver/{selfname}_SandboxVars.lua (instance-specific)
#   lgsm/config-lgsm/pzserver/SandboxVars.lua (default for all instances)
sandboxcfg_instance="${configdirserver}/${selfname}_SandboxVars.lua"
sandboxcfg_default="${configdirserver}/SandboxVars.lua"

# Check instance-specific first, then fall back to default
if [ -f "${sandboxcfg_instance}" ]; then
	sandboxcfg="${sandboxcfg_instance}"
elif [ -f "${sandboxcfg_default}" ]; then
	sandboxcfg="${sandboxcfg_default}"
else
	sandboxcfg=""
fi

# Only sync if a canonical sandbox config exists
if [ -n "${sandboxcfg}" ] && [ -f "${sandboxcfg}" ]; then
	# Ensure destination directory exists
	if [ ! -d "${servercfgdir}" ]; then
		mkdir -p "${servercfgdir}"
	fi

	# Always overwrite the destination sandbox config
	fixname="SandboxVars sync"
	fn_fix_msg_start
	cp -f "${sandboxcfg}" "${servercfgdir}/${selfname}_SandboxVars.lua"
	exitcode=$?
	fn_fix_msg_end

	if [ "${exitcode}" -eq 0 ]; then
		fn_script_log_info "Synced SandboxVars from ${sandboxcfg} to ${servercfgdir}/${selfname}_SandboxVars.lua"
	else
		fn_script_log_error "Failed to sync SandboxVars from ${sandboxcfg} to ${servercfgdir}/${selfname}_SandboxVars.lua"
	fi
fi

# ============================================================================
# Local Mods Sync
# ============================================================================
# Users can place local (non-workshop) mods at:
#   lgsm/config-lgsm/pzserver/mods/ModName/ (each mod in its own folder)
# These will be synced to ~/Zomboid/mods/
#
# Each mod folder should contain:
#   - mod.info (required - contains mod ID)
#   - media/ (mod content)
#
# The server.ini Mods= line should be configured manually or via the
# canonical config sync above.

localmodsdir="${configdirserver}/mods"

if [ -d "${localmodsdir}" ]; then
	# Ensure destination directory exists
	if [ ! -d "${zomboidmodsdir}" ]; then
		mkdir -p "${zomboidmodsdir}"
	fi

	# Count mods to sync
	modcount=$(find "${localmodsdir}" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)

	if [ "${modcount}" -gt 0 ]; then
		fixname="local mods sync (${modcount} mods)"
		fn_fix_msg_start

		# Sync each mod directory
		synced=0
		failed=0
		modlist=""

		for moddir in "${localmodsdir}"/*/; do
			if [ -d "${moddir}" ]; then
				modname=$(basename "${moddir}")

				# Check for mod.info to get the mod ID
				if [ -f "${moddir}/mod.info" ]; then
					# Extract mod ID from mod.info
					modid=$(grep -E "^id=" "${moddir}/mod.info" | cut -d'=' -f2 | tr -d '[:space:]')
					if [ -n "${modid}" ]; then
						modlist="${modlist}${modid};"
					fi
				fi

				# Sync the mod directory (rsync for efficiency, fallback to cp)
				if command -v rsync &> /dev/null; then
					rsync -a --delete "${moddir}" "${zomboidmodsdir}/${modname}/" 2>/dev/null
					result=$?
				else
					rm -rf "${zomboidmodsdir}/${modname}" 2>/dev/null
					cp -r "${moddir}" "${zomboidmodsdir}/${modname}/"
					result=$?
				fi

				if [ "${result}" -eq 0 ]; then
					((synced++))
					fn_script_log_info "Synced mod: ${modname} (ID: ${modid:-unknown})"
				else
					((failed++))
					fn_script_log_error "Failed to sync mod: ${modname}"
				fi
			fi
		done

		exitcode=0
		[ "${failed}" -gt 0 ] && exitcode=1
		fn_fix_msg_end

		# Log summary
		fn_script_log_info "Mods sync complete: ${synced} synced, ${failed} failed"

		# Log the mod IDs for reference (user should add these to server.ini Mods= line)
		if [ -n "${modlist}" ]; then
			# Remove trailing semicolon
			modlist="${modlist%;}"
			fn_script_log_info "Mod IDs for server.ini: Mods=${modlist}"
		fi
	fi
fi
