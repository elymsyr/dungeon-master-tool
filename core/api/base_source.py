import logging

logger = logging.getLogger(__name__)


class ApiSource:
    """Abstract base class for API sources."""

    def __init__(self, session):
        self.session = session

    def get_list(self, category, page=1, filters=None):
        raise NotImplementedError

    def get_supported_categories(self):
        raise NotImplementedError

    def get_documents(self):
        """Returns list of (slug, title) for available source books."""
        return []

    def get_details(self, category, index):
        """Returns RAW JSON dictionary for the given entry."""
        raise NotImplementedError

    def search(self, category, query):
        raise NotImplementedError

    def download_image_bytes(self, full_url):
        try:
            response = self.session.get(full_url, timeout=15)
            if response.status_code == 200:
                return response.content
            return None
        except Exception as e:
            logger.error("Image download error: %s", e)
            return None
