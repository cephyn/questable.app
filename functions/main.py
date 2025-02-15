# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn, options
from firebase_admin import initialize_app
from pypdf import PdfReader
import requests
from io import BytesIO
import urllib.request

initialize_app()
#
#
@https_fn.on_call()
def on_call_example(req: https_fn.CallableRequest) -> any:
    return {"text": req.data["text"]}

@https_fn.on_call()
def pdf_to_text(req: https_fn.CallableRequest) -> any:
    response = urllib.request.urlopen(req.data["url"])
    pdf_file = BytesIO(response.read())
    reader = PdfReader(pdf_file)

    text = ''
    for page in reader.pages:
        text = ''.join([text,page.extract_text(extraction_mode = "layout", layout_mode_space_vertically=False)])
    return text

    