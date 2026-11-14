from yt_dlp.postprocessor.common import PostProcessor

class FixYTMusicThumbPP(PostProcessor):
    WHEN = 'pre_process'

    def run(self, info):
        thumbnails = info.get('thumbnails') or []
        for t in thumbnails:
            url = t.get('url', '')
            if 'yt3.googleusercontent.com' in url:
                high_res_url = url.split('=')[0] + '=s5000-rj'
                info['thumbnail'] = high_res_url
                info['thumbnails'] = [{'url': high_res_url, 'width': 5000, 'height': 5000, 'id': '0'}]
                break
        return [], info