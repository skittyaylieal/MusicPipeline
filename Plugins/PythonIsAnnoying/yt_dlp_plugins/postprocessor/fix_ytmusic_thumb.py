from yt_dlp.postprocessor.common import PostProcessor

class FixYTMusicThumbPP(PostProcessor):
    def run(self, info):
        thumbnails = info.get('thumbnails') or []
        for t in thumbnails:
            url = t.get('url', '')
            if 'yt3.googleusercontent.com' in url:
                high_res_url = url.split('=')[0] + '=s5000-rj'
                
                # Rewrite top-level fallback string
                info['thumbnail'] = high_res_url
                
                # Replace thumbnails array with high-preference s5000 master
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