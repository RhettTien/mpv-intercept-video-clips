-- 电脑需要安装ffmpeg程序，并配置了环境变量
-- 字幕文件类型必须是srt格式
-- 字幕文件必须和视频在同一个文件夹中
-- 字幕文件名必须和视频文件名一致
local function parse_srt(subtitle_path)
    -- power by Claude
    local subtitles = {}
    local current_subtitle = {}
    -- 解决中文字幕乱码
    local file = io.open(subtitle_path, "r", "utf8")
    if not file then
        error("无法打开字幕文件: " .. subtitle_path)
    end
    for line in file:lines() do
        -- 移除 BOM 并去除首尾空白
        line = line:gsub("^\xEF\xBB\xBF", ""):trim()
        -- 如果是数字行（字幕序号），开始一个新的字幕条目
        if line:match("^%d+$") then
            -- 如果之前有未保存的字幕，先保存它
            if next(current_subtitle) ~= nil then
                table.insert(subtitles, current_subtitle)
            end
            -- 开始新的字幕
            current_subtitle = {
                id = tonumber(line)
            }
            -- 时间戳行
        elseif line:match("%d+:%d+:%d+,%d+%s*-->%s*%d+:%d+:%d+,%d+") then
            local start_time, end_time = line:match("(%d+:%d+:%d+,%d+)%s*-->%s*(%d+:%d+:%d+,%d+)")
            current_subtitle.start_time = start_time
            current_subtitle.end_time = end_time
            -- 文本行
        elseif line ~= "" then
            if current_subtitle.text then
                current_subtitle.text = current_subtitle.text .. "\n" .. line
            else
                current_subtitle.text = line
            end
        end
    end
    -- 添加最后一个字幕
    if next(current_subtitle) ~= nil then
        table.insert(subtitles, current_subtitle)
    end
    file:close()
    return subtitles
end

-- trim 函数
function string.trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function reduce_seconds(s)
    -- 原始时间戳
    local original_time = s
    -- 将时间戳拆分为小时、分钟、秒
    local hours, minutes, seconds_with_ms = original_time:match("(%d+):(%d+):([%d%.]+)")
    -- 将秒数转换为数值
    local seconds, ms = seconds_with_ms:match("(%d+)%.(%d+)")
    -- 转换为数值
    hours = tonumber(hours)
    minutes = tonumber(minutes)
    seconds = tonumber(seconds)
    ms = tonumber(ms)
    -- 减少5秒的时间戳
    local reduced_time = string.format("%02d:%02d:%02d.%03d",
        hours,
        minutes,
        math.max(0, seconds - 5), -- 确保秒数不会小于0
        ms
    )
    print("设置开始时间为提前5秒：" .. reduced_time)
    return reduced_time
end

local function increase_seconds(s)
    -- 原始时间戳
    local original_time = s
    -- 将时间戳拆分为小时、分钟、秒
    local hours, minutes, seconds_with_ms = original_time:match("(%d+):(%d+):([%d%.]+)")
    -- 将秒数转换为数值
    local seconds, ms = seconds_with_ms:match("(%d+)%.(%d+)")
    -- 转换为数值
    hours = tonumber(hours)
    minutes = tonumber(minutes)
    seconds = tonumber(seconds)
    ms = tonumber(ms)
    -- 增加5秒的时间戳
    local increased_time = string.format("%02d:%02d:%02d.%03d",
        hours,
        minutes,
        math.min(59, seconds + 5), -- 确保秒数不会超过59
        ms
    )
    print("设置结束时间为延后5秒：" .. increased_time)
    return increased_time
end

local function capture()
    mp.set_property_bool("pause", true)
    mp.osd_message("正在处理请稍等，处理完成后将继续播放")
    print("============================")
    -- 获取当前播放的文件路径
    local path = mp.get_property("path")
    -- 修改为本地字幕文件路径
    local subtitle_path = path:gsub("%.[^.]+$", ".srt")
    -- 读取字幕文件内容
    local subtitles = parse_srt(subtitle_path)
    -- 获取当前播放位置
    local current_time = mp.get_property_number("time-pos")
    local hours = math.floor(current_time / 3600)
    local minutes = math.floor(current_time / 60)
    local seconds = math.floor(current_time % 60)
    local milliseconds = math.floor((current_time % 1) * 1000)
    -- 格式化时间字符串
    local start_time = string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    print("现在的时间:" .. start_time)
    -- 当前播放的文件路径
    local input_file = mp.get_property_native("path")
    -- 解析结果
    for _, subtitle in ipairs(subtitles) do
        if start_time <= subtitle.end_time then
            print("开始时间:", subtitle.start_time)
            print("结束时间:", subtitle.end_time)
            print("字幕文本:", subtitle.text)
            print("开始剪切")
            -- 匹配ffmpeg时间戳格式
            local a = subtitle.start_time:gsub(",", ".")
            local b = subtitle.end_time:gsub(",", ".")
            -- 前后增加5秒的截取时间，解决字幕不准时问题
            local reduce_seconds = reduce_seconds(a)
            local increase_seconds = increase_seconds(b)
            -- 保存的文件名，默认保存到视频同级文件夹
            local temp_name = tostring(reduce_seconds) .. "~" .. tostring(increase_seconds) .. ".mp4"
            -- 优化保存的文件名
            local output_file = temp_name:gsub("%s+", "")
            local output_file = output_file:gsub(",", "-")
            local output_file = output_file:gsub(":", "-")
            -- 构建 ffmpeg 命令
            -- 如果需要压缩视频，可修改ffmpeg参数
            local command = { "ffmpeg", "-i", input_file, "-ss", reduce_seconds, "-to", increase_seconds, "-c:v",
                "libx264", "-preset", "fast",
                output_file }
            -- local command = string.format(
            --     'cmd.exe /c (echo Processing video clip from %s to %s && ffmpeg -i "%s" -ss %s -to %s -c:v libx264 -preset fast "%s")',
            --     reduce_seconds,
            --     increase_seconds,
            --     input_file,
            --     reduce_seconds,
            --     increase_seconds,
            --     output_file
            -- )
            -- os.execute(command)
            local handle = io.popen(table.concat(command, " ") .. " 2>&1")
            --local handle = io.popen('start /B /MIN cmd.exe /c %s' .. table.concat(command, " "))
            if not handle then
                print("剪切失败")
            else
                handle:close()
            end
            -- execute_ffmpeg_command(input_file, reduce_seconds, increase_seconds, output_file)
            print("============================")
            mp.osd_message("处理已完成，继续播放")
            mp.set_property_bool("pause", false)
            break
        end
    end
end

-- 添加快捷键绑定
mp.add_key_binding("Ctrl+g", "capture", capture)
