import i18n
import os

# Localization Configuration
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES_DIR = os.path.join(BASE_DIR, "locales")

i18n.load_path.append(LOCALES_DIR)
i18n.set("file_format", "yml")
i18n.set("filename_format", "{locale}.{format}")
i18n.set("fallback", "en")

def set_language(lang_code):
    """Sets the current language."""
    if lang_code.upper() == "TR":
        i18n.set("locale", "tr")
    else:
        i18n.set("locale", "en")

def tr(key, **kwargs):
    """Returns the translated string for the given key."""
    # i18n.t expects key like 'en.BTN_SAVE' if we don't specify namespace
    # but with our setup it might just be 'BTN_SAVE' if it's in the default file
    # for the current locale.
    return i18n.t(key, **kwargs)
