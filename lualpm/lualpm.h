#ifndef _LUALPM_H
#define _LUALPM_H

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "types.h"

/* DEPENDENCY FUNCTIONS ******************************************************/
/* See dep.c */

int lalpm_checkdeps(lua_State *L);
int lalpm_find_satisfier(lua_State *L);
int lalpm_find_dbs_satisfier(lua_State *L);

/* OPTIONS ******************************************************************/

/* Generated by parsing option.c:
   perl -lnE 'say "$_;" if !m{^[/\s{}]} && $_' option.c */
int lalpm_option_set_logcb(lua_State *L);
int lalpm_option_set_dlcb(lua_State *L);
int lalpm_option_set_fetchcb(lua_State *L);
int lalpm_option_set_totaldlcb(lua_State *L);
int lalpm_option_get_root(lua_State *L);
int lalpm_option_set_root(lua_State *L);
int lalpm_option_get_dbpath(lua_State *L);
int lalpm_option_set_dbpath(lua_State *L);
int lalpm_option_get_cachedirs(lua_State *L);
int lalpm_option_set_cachedirs(lua_State *L);
int lalpm_option_add_cachedir(lua_State *L);
int lalpm_option_remove_cachedir(lua_State *L);
int lalpm_option_get_logfile(lua_State *L);
int lalpm_option_set_logfile(lua_State *L);
int lalpm_option_get_lockfile(lua_State *L);
int lalpm_option_get_usesyslog(lua_State *L);
int lalpm_option_set_usesyslog(lua_State *L);
int lalpm_option_get_noupgrades(lua_State *L);
int lalpm_option_add_noupgrade(lua_State *L);
int lalpm_option_set_noupgrades(lua_State *L);
int lalpm_option_remove_noupgrade(lua_State *L);
int lalpm_option_get_noextracts(lua_State *L);
int lalpm_option_add_noextract(lua_State *L);
int lalpm_option_set_noextracts(lua_State *L);
int lalpm_option_remove_noextract(lua_State *L);
int lalpm_option_get_ignorepkgs(lua_State *L);
int lalpm_option_add_ignorepkg(lua_State *L);
int lalpm_option_set_ignorepkgs(lua_State *L);
int lalpm_option_remove_ignorepkg(lua_State *L);
int lalpm_option_get_ignoregrps(lua_State *L);
int lalpm_option_add_ignoregrp(lua_State *L);
int lalpm_option_set_ignoregrps(lua_State *L);
int lalpm_option_remove_ignoregrp(lua_State *L);
int lalpm_option_get_arch(lua_State *L);
int lalpm_option_set_arch(lua_State *L);
int lalpm_option_set_usedelta(lua_State *L);
int lalpm_option_get_localdb(lua_State *L);
int lalpm_option_get_syncdbs(lua_State *L);
int lalpm_option_get_checkspace(lua_State *L);
int lalpm_option_set_checkspace(lua_State *L);


/* TRANSACTIONS */
/* trans.c */

int lalpm_trans_init(lua_State *L);
int lalpm_trans_prepare(lua_State *L);
int lalpm_trans_commit(lua_State *L);
int lalpm_trans_interrupt(lua_State *L);
int lalpm_trans_release(lua_State *L);
int lalpm_trans_get_flags(lua_State *L);
int lalpm_trans_get_add(lua_State *L);
int lalpm_trans_get_remove(lua_State *L);

/* TRANSACTION SYNCING PACKAGES */
/* sync.c */

int lalpm_sync_sysupgrade(lua_State *L);
/* int lalpm_sync_target(lua_State *L); */
/* int lalpm_sync_dbtarget(lua_State *L); */
/* int lalpm_add_target(lua_State *L); */
/* int lalpm_remove_target(lua_State *L); */
int lalpm_add_pkg(lua_State *L);
int lalpm_remove_pkg(lua_State *L);

int lalpm_pkg_load(lua_State *L);

#endif
