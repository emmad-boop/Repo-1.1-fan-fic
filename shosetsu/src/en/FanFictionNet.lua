-- {"id":7710002,"ver":"1.0.0","libVer":"1.0.0","author":"emmad-boop","repo":"https://github.com/emmad-boop/Repo-1.1-fan-fic","dep":[]}
--
-- FanFiction.Net extension for Shosetsu.

local baseURL = "https://www.fanfiction.net"
local imageURL = "https://raw.githubusercontent.com/emmad-boop/Repo-1.1-fan-fic/main/shosetsu/icons/FanFictionNet.png"

local id = 7710002

local function urlencode(s)
    if s == nil then return "" end
    return (tostring(s):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function trim(s)
    if s == nil then return nil end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function fixImage(src)
    if src == nil or src == "" then return nil end
    if src:sub(1, 2) == "//" then
        return "https:" .. src
    end
    return src
end

local FID_CATEGORY = 100
local FID_SORT = 101
local FID_GENRE1 = 102
local FID_GENRE2 = 103
local FID_RATING = 104
local FID_LENGTH = 105
local FID_STATUS = 106
local FID_LANGUAGE = 107

local SORT_LABELS = {
    "Update Date",
    "Publish Date",
    "Reviews",
    "Favorites",
    "Follows"
}

local SORT_VALS = {
    [0] = 1,
    [1] = 2,
    [2] = 3,
    [3] = 4,
    [4] = 5
}

local GENRE_LABELS = {
    "Any",
    "Adventure",
    "Angst",
    "Crime",
    "Drama",
    "Family",
    "Fantasy",
    "Friendship",
    "General",
    "Horror",
    "Humor",
    "Hurt/Comfort",
    "Mystery",
    "Parody",
    "Poetry",
    "Romance",
    "Sci-Fi",
    "Spiritual",
    "Supernatural",
    "Suspense",
    "Tragedy",
    "Western"
}

local RATING_LABELS = {
    "All",
    "K",
    "K+",
    "T",
    "M",
    "K -> T"
}

local RATING_VALS = {
    [0] = 10,
    [1] = 1,
    [2] = 2,
    [3] = 3,
    [4] = 4,
    [5] = 103
}

local LENGTH_LABELS = {
    "Any",
    "< 1k",
    "> 5k",
    "> 10k",
    "> 20k",
    "> 40k",
    "> 60k",
    "> 100k"
}

local LENGTH_VALS = {
    [0] = 0,
    [1] = 1,
    [2] = 5,
    [3] = 10,
    [4] = 20,
    [5] = 40,
    [6] = 60,
    [7] = 100
}

local STATUS_LABELS = {
    "Any",
    "In-Progress",
    "Complete"
}

local LANGUAGE_LABELS = {
    "Any",
    "English",
    "Spanish",
    "French",
    "Portuguese",
    "German"
}

local LANGUAGE_VALS = {
    [0] = 0,
    [1] = 1,
    [2] = 2,
    [3] = 3,
    [4] = 7,
    [5] = 8
}

local searchFilters = {
    TextFilter(
        FID_CATEGORY,
        "Fandom path (e.g. book/Harry-Potter, anime/Naruto)"
    ),
    DropdownFilter(FID_SORT, "Sort by", SORT_LABELS),
    DropdownFilter(FID_GENRE1, "Genre", GENRE_LABELS),
    DropdownFilter(FID_GENRE2, "Genre (second)", GENRE_LABELS),
    DropdownFilter(FID_RATING, "Rating", RATING_LABELS),
    DropdownFilter(FID_LENGTH, "Length", LENGTH_LABELS),
    DropdownFilter(FID_STATUS, "Status", STATUS_LABELS),
    DropdownFilter(FID_LANGUAGE, "Language", LANGUAGE_LABELS),
}

local GENRE_SET = {}

for i = 2, #GENRE_LABELS do
    GENRE_SET[GENRE_LABELS[i]] = true
end

GENRE_SET["Hurt-Comfort"] = true

local function filterQuery(data, pageParam)
    local p = {}

    p[#p + 1] = "srt=" .. SORT_VALS[data[FID_SORT] or 0]
    p[#p + 1] = "r=" .. RATING_VALS[data[FID_RATING] or 0]

    local g1 = data[FID_GENRE1] or 0

    if g1 > 0 then
        p[#p + 1] = "g1=" .. g1
    end

    local g2 = data[FID_GENRE2] or 0

    if g2 > 0 then
        p[#p + 1] = "g2=" .. g2
    end

    local len = LENGTH_VALS[data[FID_LENGTH] or 0]

    if len > 0 then
        p[#p + 1] = "len=" .. len
    end

    local s = data[FID_STATUS] or 0

    if s > 0 then
        p[#p + 1] = "s=" .. s
    end

    local lan = LANGUAGE_VALS[data[FID_LANGUAGE] or 0]

    if lan > 0 then
        p[#p + 1] = "lan=" .. lan
    end

    local page = data[PAGE]

    if page and page > 1 then
        p[#p + 1] = pageParam .. "=" .. page
    end

    return table.concat(p, "&")
end

local function parseList(document)
    local scope = document:selectFirst("#content_wrapper_inner")

    if scope == nil then
        scope = document
    end

    return mapNotNil(
        scope:select(".z-list"),
        function(row)
            local a = row:selectFirst("a.stitle")

            if a == nil then
                return nil
            end

            local img = row:selectFirst("a.stitle img")

            local src = nil

            if img then
                src = img:attr("data-original")

                if src == nil or src == "" then
                    src = img:attr("src")
                end
            end

            return Novel {
                title = a:text(),
                link = a:attr("href"),
                imageURL = fixImage(src),
            }
        end
    )
end

local function shrinkURL(url)
    return (url:gsub("^.-fanfiction%.net", ""))
end

local function expandURL(url)
    if url:match("^https?://") then
        return url
    end

    return baseURL .. url
end

local function splitMeta(meta)
    local parts = {}

    for seg in (meta .. " - "):gmatch("(.-) %- ") do
        parts[#parts + 1] = trim(seg)
    end

    return parts
end

local function parseNovel(novelURL, loadChapters)
    local doc = GETDocument(expandURL(novelURL))

    local profile = doc:selectFirst("#profile_top")

    if profile == nil then
        return NovelInfo {
            title = "Unknown",
            description = ""
        }
    end

    local titleEl = profile:selectFirst("b.xcontrast_txt")
    local title = titleEl and trim(titleEl:text()) or "Unknown"

    local authorEl =
        profile:selectFirst("a.xcontrast_txt[href^=\"/u/\"]")

    local author =
        authorEl and trim(authorEl:text()) or "Unknown"

    local summaryEl =
        profile:selectFirst("div.xcontrast_txt")

    local summary =
        summaryEl and trim(summaryEl:text()) or ""

    local imgEl =
        profile:selectFirst("img.cimage")

    local cover = nil

    if imgEl then
        local src = imgEl:attr("data-original")

        if src == nil or src == "" then
            src = imgEl:attr("src")
        end

        cover = fixImage(src)
    end

    local metaEl =
        profile:selectFirst("span.xgray.xcontrast_txt")

    local meta =
        metaEl and trim(metaEl:text()) or ""

    meta = meta:gsub("Hurt/Comfort", "Hurt-Comfort")

    local status =
        meta:find("Status: Complete")
        and NovelStatus.COMPLETED
        or NovelStatus.PUBLISHING

    local parts = splitMeta(meta)

    local language = table.remove(parts, 1)

    local genres = {}

    if parts[1] then
        local candidate = {}
        local allGenre = true

        for g in parts[1]:gmatch("[^/]+") do
            g = trim(g)

            candidate[#candidate + 1] = g

            if not GENRE_SET[g] then
                allGenre = false
            end
        end

        if allGenre and #candidate > 0 then
            genres = candidate
            table.remove(parts, 1)
        end
    end

    local tags = {}

    if language and language ~= "" then
        tags[#tags + 1] = "Language: " .. language
    end

    local charParts = {}

    for _, seg in ipairs(parts) do
        local key = seg:match("^([%w]+):")

        if not key then
            charParts[#charParts + 1] = seg
        end
    end

    local charsText =
        table.concat(charParts, " - ")

    for c in charsText:gsub("[%[%]]", ""):gmatch("[^,]+") do
        c = trim(c)

        if c ~= "" then
            tags[#tags + 1] = "Character: " .. c
        end
    end

    local info = NovelInfo {
        title = title,
        imageURL = cover or imageURL,
        description = summary,
        authors = {author},
        genres = genres,
        tags = tags,
        status = status,
    }

    if loadChapters then
        local storyId =
            novelURL:match("/s/(%d+)")

        local slug =
            novelURL:match("/s/%d+/%d+/([^/?]+)") or ""

        local chapters = {}

        local chapSelect =
            doc:selectFirst("#chap_select")

        if chapSelect then
            local order = 0

            map(
                chapSelect:select("option"),
                function(opt)
                    order = order + 1

                    chapters[#chapters + 1] =
                        NovelChapter {
                            order = order,
                            title = opt:text(),
                            link =
                                "/s/" ..
                                storyId ..
                                "/" ..
                                opt:attr("value") ..
                                "/" ..
                                slug,
                        }
                end
            )
        else
            chapters[1] =
                NovelChapter {
                    order = 1,
                    title = title,
                    link =
                        "/s/" ..
                        storyId ..
                        "/1/" ..
                        slug,
                }
        end

        info:setChapters(AsList(chapters))
    end

    return info
end

local function getPassage(chapterURL)
    local doc =
        GETDocument(expandURL(chapterURL))

    map(
        doc:select("div.google-auto-placed"),
        function(ad)
            ad:remove()
        end
    )

    local story =
        doc:selectFirst("#storytext")
        or doc:selectFirst("#storytextp")

    if story == nil then
        return "Could not load chapter."
    end

    return pageOfElem(story)
end

local function browse(data)
    local category =
        trim(data[FID_CATEGORY] or "")

    if category == nil or category == "" then
        return parseList(
            GETDocument(baseURL .. "/j/0/0/0/")
        )
    end

    category =
        category:gsub("^/*", ""):gsub("/*$", "")

    return parseList(
        GETDocument(
            baseURL ..
            "/" ..
            category ..
            "/?" ..
            filterQuery(data, "p")
        )
    )
end

local function search(data)
    local url =
        baseURL ..
        "/search/?ready=1&type=story&keywords=" ..
        urlencode(data[QUERY]) ..
        "&" ..
        filterQuery(data, "ppage")

    return parseList(GETDocument(url))
end

return {
    id = id,
    name = "FanFiction.Net",
    baseURL = baseURL,
    imageURL = imageURL,

    chapterType = ChapterType.HTML,

    hasCloudFlare = true,
    hasSearch = true,
    isSearchIncrementing = true,
    startIndex = 1,

    shrinkURL = shrinkURL,
    expandURL = expandURL,

    listings = {
        Listing(
            "Browse / Just In",
            true,
            browse
        ),
    },

    searchFilters = searchFilters,

    parseNovel = parseNovel,
    getPassage = getPassage,
    search = search,
}
