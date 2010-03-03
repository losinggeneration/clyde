module(..., package.seeall)
local util = require "clydelib.util"
local utilcore = require "clydelib.utilcore"
local alpm = require "lualpm"
local socket = require "socket"
colorize = require "clydelib.colorize"
local g = utilcore.gettext
local printf = util.printf
local vfprintf = util.vfprintf
local getcols = util.getcols
local yesno = util.yesno
local list_display = util.list_display

local rate_last
local xfered_last
local list_xfered = 0
local list_total = 0
local initial_time

local prevpercent = 0

local on_progress = false
local output = {}

local last_time = 0
function get_update_timediff(first_call)
    local retval = 0.0
    return function(first_call)
        if(first_call) then
            last_time = socket.gettime()
        else
            local this_time = socket.gettime()
            local diff_time = this_time - last_time
            retval = diff_time

            if (retval < .2) then
                retval = 0.0
            else
                last_time = this_time
                --print("update retval: "..retval)
            end
        end

        return retval
    end
end

local lasthash, mouth = 0, 0
function fill_progress(bar_percent, disp_percent, proglen)
    local C = colorize

        local hashlen = proglen - 8
        local hash = math.floor(bar_percent * hashlen / 100)

        if (bar_percent == 0) then
            lasthash = 0
            mouth = 0
        end

        if (proglen > 8) then
            printf(" [")
            for i = hashlen, 1, -1 do
                if (config.chomp) then
                    if (i > hashlen - hash) then
                        printf("-")
                    elseif (i == hashlen - hash ) then
                        if (lasthash == hash) then
                            if (mouth ~= 0) then
                                printf(C.yel(string.char(0xe2, 0x88, 0xa9)).." "..C.yelb("C"))
--                                printf("\27[1;33m∩ C\27[m")
                            else
                                printf(C.yel(string.char(0xe2, 0x88, 0xa9)).." "..C.yelb("c"))
--                                printf("\27[1;33m∩ c\27[m")
                            end
                        else
                            lasthash = hash
                            if mouth == 1 then mouth = 0 else mouth = 1 end
                            if (mouth ~= 0) then
                                printf(C.yel(string.char(0xe2, 0x88, 0xa9)).." "..C.yelb("C"))
--                                printf("\27[1;33m∩ C\27[m")
                            else
                                printf(C.yel(string.char(0xe2, 0x88, 0xa9)).." "..C.yelb("c"))
--                                printf("\27[1;33m∩ c\27[m")
                            end
                        end
                    elseif (i%3 == 0) then
                        printf(C.whi("o"))
--                        printf("\27[0;37mo\27[m")
                    else
                        printf(C.whi(" "))
--                        printf("\27[0;37m \27[m")
                    end
                elseif (i > hashlen - hash) then
                    printf("#")
                else
                    printf("-")
                end
            end
            printf("]\27[K")
        end
        if (proglen > 5) then
            if (bar_percent ~= 100 and config.chomp) then
                printf("\27[3D] %3d%% ", disp_percent)
            else
                printf(" %3d%%", disp_percent)
            end
        end
        if (bar_percent == 100) then
            printf("\n")
        else
            if (config.chomp) then
                printf("\27[1A\r")
            else
                printf("\r")
            end
        end
        io.stdout:flush()
end

function cb_trans_progress(event, pkgname, percent, howmany, remain)
    local timediff
    local infolen = 50
    local tmp, digits, textlen, opr
    local len, wclen, wcwid, padwid
    local wcstr

    if (config.noprogressbar) then
        return
    end

    if (percent == 0) then
        timediff = get_update_timediff(true)()
    else
        timediff = get_update_timediff(false)()
    end

    if (percent > 0 and percent < 100 and not timediff) then
        return
    end

    if (not pkgname or percent == prevpercent) then
        return
    end

    prevpercent = percent

    local lookuptbl = {
        ["T_P_ADD_START"] = function() opr = g("installing") end;
        ["T_P_UPGRADE_START"] = function() opr = g("upgrading") end;
        ["T_P_REMOVE_START"] = function() opr = g("removing") end;
        ["T_P_CONFLICTS_START"] = function() opr = g("checking for file conflicts") end;
    }
    if (lookuptbl[event]) then
        lookuptbl[event]()
    else
        printf("error: unknown event type")
    end

    digits = #tostring(howmany)
    textlen = infolen -3 - (2 * digits)
    len = #opr + (#pkgname or 0)
    wcstr = string.format("%s %s", opr, pkgname)

    padwid = textlen - len - 3
    if (padwid <  0) then
        local mpadwid = padwid * -1
        local i = textlen - 5
        wcstr = string.sub(wcstr, 1, i)
        wcstr = wcstr.."..."
        padwid = 0
    end
    printf("(%d/%d) %s %s", remain, howmany, wcstr, string.rep(" ", padwid ))
    fill_progress(percent, percent, getcols() - infolen)

    if (percent == 100) then
        on_progress = false
        for i, tbl in ipairs(output) do
            vfprintf("stdout", tbl.level, "%s", tbl.message)
        end
        output = {}
        io.stdout:flush()
    else
        on_progress = true
    end
end

function cb_dl_total(total)
    list_total = total
    if (total == 0) then
        list_xfered = 0
    end
end

function cb_dl_progress(filename, file_xfered, file_total)
    local infolen = 50
    local filenamelen = infolen - 27
    local fname, len, wclen, padwid, wcfname

    local totaldownload = false
    local xfered, total
    local file_percent, total_percent = 0, 0
    local rate, timediff, f_xfered = 0.0, 0.0, 0.0
    local eta_h, eta_m, eta_s = 0, 0, 0
    local rate_size, xfered_size = "K", "K"

    if (config.noprogressbar or file_total == -1) then
        if (file_xfered == 0) then
            printf(g("downloading %s...\n"), filename)
            io.stdout:flush()
        end
        return
    end

    if (config.totaldownload and list_total ~= 0) then
        if (list_xfered + file_total <= list_total) then
            totaldownload = true
        else
            list_xfered = 0
            list_total = 0
        end
    end

    if (totaldownload) then
        xfered = list_xfered + file_xfered
        total = list_total
    else
        xfered = file_xfered
        total = file_total
    end

    if (xfered > total) then
        return
    end

    if (file_xfered == 0) then
        if (not totaldownload or (totaldownload and list_xfered == 0)) then
            initial_time = socket.gettime()
            xfered_last = 0
            rate_last = 0
            timediff = get_update_timediff(true)()
        end
    elseif (file_xfered == file_total) then
        local current_time = socket.gettime()
        timediff = current_time - initial_time
        rate = xfered / (timediff * 1024)

        eta_s = math.floor(timediff + .5)
    else
        timediff = get_update_timediff(false)()

        if (timediff < .02) then
            return
        end
        rate = (xfered - xfered_last) / (timediff * 1024)
        rate = (rate + 2 * rate_last) / 3
        eta_s = math.floor((total - xfered) / (rate * 1024))
        rate_last = rate
        xfered_last = xfered
    end

    file_percent = math.floor(file_xfered / file_total * 100)

    if (totaldownload) then
        total_percent = math.floor((list_xfered + file_xfered) / list_total * 100)

        if (file_xfered == file_total) then
            list_xfered = list_xfered + file_total
        end
    end

    eta_h = math.floor(eta_s / 3600)
    eta_s = eta_s - (eta_h * 3600)
    eta_m = math.floor(eta_s / 60)
    eta_s = eta_s - (eta_m * 60)
    fname = filename
    if (fname:match("%.db%.tar%.gz$")) then
        fname = fname:match("(.+)%.db%.tar%.gz$")
    elseif (fname:match("%.pkg%.tar%.gz$")) then
        fname = fname:match("(.+)%.pkg%.tar%.gz$")
    end

    len = #filename
    wcfname = fname:sub(1, len)
    padwid = filenamelen - #wcfname
    if (padwid < 0) then
        local i = filenamelen - 3
        wcfname = wcfname:sub(1, i)
        wcfname = wcfname.."..."
        padwid = 0
    end

    if (rate > 2048) then
        rate = rate / 1024
        rate_size = "M"
        if (rate > 2048) then
            rate = rate / 1024
            rate_size = "G"
        end
    end

    f_xfered = xfered / 1024
    if (f_xfered > 2048) then
        f_xfered = f_xfered / 1024
        xfered_size = "M"
        if (f_xfered > 2048) then
            f_xfered = f_xfered / 1024
            xfered_size = "G"
        end
    end
    printf("%s%s %6.1f%s %6.1f%s/s %02d:%02d:%02d", wcfname, string.rep(" ", padwid),
        f_xfered, xfered_size, rate, rate_size,
        tonumber(eta_h), tonumber(eta_m), tonumber(eta_s))

    if (totaldownload) then
        fill_progress(file_percent, total_percent, getcols() - infolen)
    else
        fill_progress(file_percent, file_percent, getcols() - infolen)
    end
end

function cb_log(level, message)
    if (not message or #message == 0) then
        return
    end
    if (on_progress) then
        table.insert(output, {level = level; message = message})
    else
        vfprintf("stdout", level, "%s", message)
    end
end


cb_trans_evt = {
    ["T_E_CHECKDEPS_START"] = function()
        printf(g("checking dependencies...\n"))
        io.stdout:flush()
    end;
    ["T_E_FILECONFLICTS_START"] = function()
        if (config.noprogressbar) then
            printf(g("checking for file conflicts...\n"))
        end
        io.stdout:flush()
    end;
    ["T_E_RESOLVEDEPS_START"] = function()
        printf(g("resolving dependencies...\n"))
        io.stdout:flush()
    end;
    ["T_E_INTERCONFLICTS_START"] = function()
        printf(g("looking for inter-conflicts...\n"))
        io.stdout:flush()
    end;
    ["T_E_ADD_START"] = function(data1)
        if (config.noprogressbar) then
            printf(g("installing %s...\n"), data1:pkg_get_name())
        end
        io.stdout:flush()
    end;
    ["T_E_ADD_DONE"] = function(data1)
        alpm.logaction(string.format("installed %s (%s)\n",
            data1:pkg_get_name(),
            data1:pkg_get_version()))
            --TODO: write display_optdepends
            --display_optdepends(data1)
        io.stdout:flush()
        end;
    ["T_E_REMOVE_START"] = function(data1)
        if (config.noprogressbar) then
            printf(g("removing %s...\n"), data1:pkg_get_name())
        end
        io.stdout:flush()
    end;
    ["T_E_REMOVE_DONE"] = function(data1)
        alpm.logaction(string.format("removed %s (%s)\n",
            data1:pkg_get_name(),
            data1:pkg_get_version()))
        io.stdout:flush()
    end;
    ["T_E_UPGRADE_START"] = function(data1)
        if (config.noprogressbar) then
            printf(g("upgrading %s...\n"), data1:pkg_get_name())
        end
        io.stdout:flush()
    end;
    ["T_E_UPGRADE_DONE"] = function(data1, data2)
        alpm.logaction(string.format("upgraded %s (%s -> %s)\n",
            data1:pkg_get_name(),
            data2:pkg_get_version(),
            data1:pkg_get_version()))
            --TODO: write display_new_optdepends
            --display_new_optdepends(data2, data1)
        io.stdout:flush()
    end;
    ["T_E_INTEGRITY_START"] = function()
        printf(g("checking package integrity...\n"))
        io.stdout:flush()
    end;
    ["T_E_DELTA_INTEGRITY_START"] = function()
        printf(g("checking delta integrity...\n"))
        io.stdout:flush()
    end;
    ["T_E_DELTA_PATCHES_START"] = function()
        printf(g("applying deltas...\n"))
        io.stdout:flush()
    end;
    ["T_E_DELTA_PATCH_START"] = function(data1, data2)
        printf(g("generating %s with %s... "), data1, data2)
        io.stdout:flush()
    end;
    ["T_E_DELTA_PATCH_DONE"] = function()
        printf(g("success!\n"))
        io.stdout:flush()
    end;
    ["T_E_DELTA_PATCH_FAILED"] = function()
        printf(f("failed.\n"))
        io.stdout:flush()
    end;
    ["T_E_SCRIPTLET_INFO"] = function(data1)
        printf("%s", data1)
        io.stdout:flush()
    end;
    ["T_E_RETRIEVE_START"] = function(data1)
        printf(g(":: Retrieving packages from %s...\n"), data1)
        io.stdout:flush()
    end;
    ["T_E_FILECONFLICTS_DONE"] = function()
        io.stdout:flush()
    end;
    ["T_E_CHECKDEPS_DONE"] = function()
        io.stdout:flush()
    end;
    ["T_E_RESOLVEDEPS_DONE"] = function()
        io.stdout:flush()
    end;
    ["T_E_INTERCONFLICTS_DONE"] = function()
        io.stdout:flush()
    end;
    ["T_E_INTEGRITY_DONE"] = function()
        io.stdout:flush()
    end;
    ["T_E_DELTA_INTEGRITY_DONE"] = function()
        io.stdout:flush()
    end;
    ["T_E_DELTA_PATCHES_DONE"] = function()
        io.stdout:flush()
    end;
}

cb_trans_conv = {
    ["T_C_INSTALL_IGNOREPKG"] = function(data1)
        local response = yesno(g(":: %s is in IgnorePkg/IgnoreGroup. Install anyway?"),
            data1:pkg_get_name())
        return response
    end;
    ["T_C_REPLACE_PKG"] = function(data1, data2, data3)
        local response = yesno(g(":: Replace %s with %s/%s?"),
            data1:pkg_get_name(),
            data3, data2:pkg_get_name())
        return response
    end;
    ["T_C_CONFLICT_PKG"] = function(data1, data2)
        local response = yesno(g(":: %s conflicts with %s. Remove %s?"),
            data1, data2, data2)
        return response
    end;
    ["T_C_REMOVE_PKGS"] = function(data1)
        local namelist = {}
        for i, pkg in ipairs(data1) do
            table.insert(namelist, pkg:pkg_get_name())
        end
        printf(g(":: the following pakage(s) cannot be upgraded due to unresolvable dependencies:\n"))
        list_display("     ", namelist)
        local response = yesno(g("\nDo you want to skip the above package(s) for this upgrade?"))
        return response
    end;
    ["T_C_LOCAL_NEWER"] = function(data1)
        local response
        if (not config.op_s_downloadonly) then
            response = yesno(g(":: %s-%s: local version is newer. Upgrade anyway?"),
                data1:pkg_get_name(), data1:pkg_get_version())
        else
            response = true
        end
    end;
    ["T_C_CORRUPTED_PKG"] = function(data1)
        local response = yesno(g(":: File %s is corrupted. Do you want to delete it?"),
            data1)
    end;
}
