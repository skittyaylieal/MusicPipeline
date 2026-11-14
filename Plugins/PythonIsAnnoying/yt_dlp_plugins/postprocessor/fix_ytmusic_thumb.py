from yt_dlp.postprocessor.common import PostProcessor

class FixYTMusicThumbPP(PostProcessor):
    def __init__(self, downloader=None, **kwargs):
        super().__init__(downloader)
        self._when = 'pre_process'

    def run(self, info):
        thumbnails = info.get('thumbnails') or []
        for t in thumbnails:
            url = t.get('url', '')
            if 'yt3.googleusercontent.com' in url:
                high_res_url = url.split('=')[0] + '=s5000-rj'
                info['thumbnail'] = high_res_url
                
                # Replace list with single s5000 entry carrying high preference
                info['thumbnails'] = [{
                    'url': high_res_url,
                    'width': 5000,
                    'height': 5000,
                    'id': 'ytmusic_s5000',
                    'preference': 1000,
                }]
                self.to_screen(f'[FixYTMusicThumb] Rewrote thumbnail to 5000x5000 master: {high_res_url}')
                break
        return [], info