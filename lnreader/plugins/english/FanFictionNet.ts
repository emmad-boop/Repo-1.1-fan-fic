import { fetchApi } from '@libs/fetch';
import { Plugin } from '@/types/plugin';
import { Filters } from '@libs/filterInputs';
import { load as parseHTML } from 'cheerio';
import { defaultCover } from '@libs/defaultCover';
import { NovelStatus } from '@libs/novelStatus';

class FanFictionNet implements Plugin.PluginBase {
  id = 'fanfictionnet';
  name = 'FanFiction.net';
  version = '1.0.0';
  site = 'https://www.fanfiction.net/';
  icon = '';

  filters: Filters | undefined = undefined;

  private parseNovels(html: string): Plugin.NovelItem[] {
    const $ = parseHTML(html);
    const novels: Plugin.NovelItem[] = [];

    $('.z-list').each((_, el) => {
      const titleEl = $(el).find('a.stitle').first();
      const url = titleEl.attr('href');

      if (!url) return;

      novels.push({
        name: titleEl.text().trim(),
        path: url.replace(/^\/+/, ''),
        cover:
          $(el).find('a.stitle img').attr('data-original') ||
          $(el).find('a.stitle img').attr('src') ||
          defaultCover,
      });
    });

    return novels;
  }

  async popularNovels(
    pageNo: number,
    _options: Plugin.PopularNovelsOptions<typeof this.filters>,
  ): Promise<Plugin.NovelItem[]> {
    const url =
      this.site +
      'j/0/0/0/' +
      (pageNo > 1 ? '?p=' + pageNo : '');

    const response = await fetchApi(url);

    return this.parseNovels(await response.text());
  }

  async searchNovels(
    searchTerm: string,
    pageNo: number,
  ): Promise<Plugin.NovelItem[]> {
    const url =
      this.site +
      'search/?ready=1&type=story&keywords=' +
      encodeURIComponent(searchTerm) +
      '&ppage=' +
      pageNo;

    const response = await fetchApi(url);

    return this.parseNovels(await response.text());
  }

  async parseNovel(
    novelPath: string,
  ): Promise<Plugin.SourceNovel> {
    const novelUrl =
      new URL(novelPath, this.site).toString();

    const response = await fetchApi(novelUrl);
    const $ = parseHTML(await response.text());

    const profile = $('#profile_top');

    const meta =
      profile
        .find('span.xgray.xcontrast_txt')
        .first()
        .text()
        .trim();

    const title =
      profile
        .find('b.xcontrast_txt')
        .first()
        .text()
        .trim() || 'Untitled';

    const author =
      profile
        .find('a.xcontrast_txt[href^="/u/"]')
        .first()
        .text()
        .trim();

    const summary =
      profile
        .find('div.xcontrast_txt')
        .first()
        .text()
        .trim();

    const novel: Plugin.SourceNovel = {
      path: novelPath,
      name: title,

      cover:
        profile.find('img.cimage').attr('data-original') ||
        profile.find('img.cimage').attr('src') ||
        defaultCover,

      author,

      status: meta.includes('Complete')
        ? NovelStatus.Completed
        : NovelStatus.Publishing,

      genres: meta,
      summary,
      chapters: [],
    };

    $('#chap_select option').each((_, el) => {
      const value = $(el).attr('value');

      if (!value) return;

      novel.chapters.push({
        name: $(el).text().trim(),
        path: novelPath + '/' + value,
      });
    });

    if (novel.chapters.length === 0) {
      novel.chapters.push({
        name: title,
        path: novelPath,
      });
    }

    return novel;
  }

  async parseChapter(
    chapterPath: string,
  ): Promise<string> {
    const chapterUrl =
      new URL(chapterPath, this.site).toString();

    const response =
      await fetchApi(chapterUrl);

    const $ =
      parseHTML(await response.text());

    return $('#storytext').html() || '';
  }
}

export default new FanFictionNet();
