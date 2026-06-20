import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.core.config import get_settings
from backend.app.core.firebase import initialize_firebase
from firebase_admin import firestore

def main():
    settings = get_settings()
    initialize_firebase(settings)
    
    client = firestore.client()
    collection_ref = client.collection("products")
    docs = collection_ref.stream()
    
    batch = client.batch()
    count = 0
    
    for doc in docs:
        doc_ref = collection_ref.document(doc.id)
        # Update imageUrls with the provided URL
        batch.update(doc_ref, {
            "imageUrls": ["https://images.unsplash.com/photo-1558591710-4b4a1ae0f04d?w=600&auto=format&fit=crop&q=60&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8YmFja2dyb3VuZHxlbnwwfHwwfHx8MA%3D%3D"]
        })
        count += 1
        
        if count % 100 == 0:
            batch.commit()
            batch = client.batch()
            
    if count % 100 != 0:
        batch.commit()
        
    print(f"Updated {count} products with the new image URL.")

if __name__ == "__main__":
    main()
