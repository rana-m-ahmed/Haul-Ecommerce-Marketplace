# 08 - Test Log

Append a new entry every session. Do not overwrite history; this file is the record that QA actually ran continuously instead of getting saved for the end.

---

### Sprint 0 - Foundation - 2026-06-17 / Codex

**Command(s) run:**
```powershell
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m openapi_spec_validator progress\01_API_CONTRACT.yaml
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -c "import json; data=json.load(open('backend/seed/products.json', encoding='utf-8')); print('count', len(data)); print('categories', sorted(set(p['category'] for p in data))); print('out_of_stock', sum(p['inventory']==0 for p in data)); print('sale', sum(p['isSale'] for p in data)); print('new', sum(p['isNew'] for p in data)); print('missing_image', sum(len(p['imageUrls'])==0 for p in data)); print('multi_variant', sum(len(p['colors'])>1 or len(p['materials'])>1 for p in data))"
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m uvicorn backend.mock.app:app --host 127.0.0.1 --port 8000
curl.exe -sS http://127.0.0.1:8000/health
curl.exe -sS -X POST http://127.0.0.1:8000/search -H "Content-Type: application/json" --data "{\"query\":\"minimalist lamp\",\"category\":\"home\",\"sortBy\":\"newest\",\"pageSize\":12,\"pageToken\":null}"
curl.exe -sS http://127.0.0.1:8000/products/p017
curl.exe -sS -X POST http://127.0.0.1:8000/products/batch -H "Content-Type: application/json" --data "{\"ids\":[\"p017\",\"p021\",\"p999\"]}"
curl.exe -sS http://127.0.0.1:8000/recommendations/u_001
curl.exe -sS -X POST http://127.0.0.1:8000/visual-search -F "image=@progress/01_API_CONTRACT.yaml" -F "mlKitLabels=shoe"
curl.exe -sS -X POST http://127.0.0.1:8000/explain-product -H "Content-Type: application/json" --data "{\"uid\":\"u_001\",\"productId\":\"p017\"}"
curl.exe -sS -X POST http://127.0.0.1:8000/events -H "Content-Type: application/json" --data "{\"eventType\":\"product_view\",\"productId\":\"p017\",\"category\":\"home\",\"sourceScreen\":\"home\",\"metadata\":{\"dwellMs\":4200}}"
curl.exe -sS -X POST http://127.0.0.1:8000/cart/validate -H "Content-Type: application/json" --data "{\"items\":[{\"productId\":\"p017\",\"variantId\":\"clay-white\",\"quantity\":1,\"priceSnapshot\":64.0}]}"
curl.exe -sS -X POST http://127.0.0.1:8000/create-payment-intent -H "Content-Type: application/json" --data "{\"shippingAddress\":{\"line1\":\"123 Main St\",\"line2\":\"Apt 4\",\"city\":\"Austin\",\"region\":\"TX\",\"postalCode\":\"78701\",\"country\":\"US\"}}"
curl.exe -sS -X POST http://127.0.0.1:8000/orders/confirm -H "Content-Type: application/json" --data "{\"paymentIntentId\":\"pi_test_123\"}"
curl.exe -sS http://127.0.0.1:8000/orders/u_001
git branch backend/main main
git branch app/main main
git branch --list
```

**Result summary:**
```text
progress\01_API_CONTRACT.yaml: OK

count 50
categories ['accessories', 'electronics', 'fashion', 'fitness', 'home', 'skincare']
out_of_stock 6
sale 13
new 12
missing_image 6
multi_variant 41

git branch --list:
  app/main
  backend/main
* main
```

**Live verification performed:**
```text
COMMAND: curl.exe -sS http://127.0.0.1:8000/health
{"status":"ok","version":"0.1.0","timestamp":"2026-06-17T12:00:00Z"}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/search -H "Content-Type: application/json" --data "{...}"
{"products":[{"id":"p017","name":"Arc Ceramic Table Lamp","description":"A softly curved ceramic lamp for warm desk and bedside lighting.","price":64.0,"salePrice":null,"category":"home","colors":["clay","white"],"materials":["ceramic","linen"],"style":["minimal","warm"],"tags":["lamp","lighting","decor"],"searchTokens":["arc","ceramic","table","lamp","home"],"imageUrls":["https://hual-assets.web.app/products/p017-1.jpg"],"rating":4.7,"reviewCount":91,"inventory":18,"isNew":false,"isSale":false,"createdAt":"2026-05-10T09:00:00Z"}],"pageToken":"next_home_12","total":1,"appliedFilters":{"category":"home","sortBy":"newest"}}

COMMAND: curl.exe -sS http://127.0.0.1:8000/products/p017
{"id":"p017","name":"Arc Ceramic Table Lamp","description":"A softly curved ceramic lamp for warm desk and bedside lighting.","price":64.0,"salePrice":null,"category":"home","colors":["clay","white"],"materials":["ceramic","linen"],"style":["minimal","warm"],"tags":["lamp","lighting","decor"],"searchTokens":["arc","ceramic","table","lamp","home"],"imageUrls":["https://hual-assets.web.app/products/p017-1.jpg"],"rating":4.7,"reviewCount":91,"inventory":18,"isNew":false,"isSale":false,"createdAt":"2026-05-10T09:00:00Z"}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/products/batch -H "Content-Type: application/json" --data "{...}"
{"products":[{"id":"p017","name":"Arc Ceramic Table Lamp","description":"A softly curved ceramic lamp for warm desk and bedside lighting.","price":64.0,"salePrice":null,"category":"home","colors":["clay","white"],"materials":["ceramic","linen"],"style":["minimal","warm"],"tags":["lamp","lighting","decor"],"searchTokens":["arc","ceramic","table","lamp","home"],"imageUrls":["https://hual-assets.web.app/products/p017-1.jpg"],"rating":4.7,"reviewCount":91,"inventory":18,"isNew":false,"isSale":false,"createdAt":"2026-05-10T09:00:00Z"}],"missingIds":["p999"]}

COMMAND: curl.exe -sS http://127.0.0.1:8000/recommendations/u_001
{"products":[{"id":"p017","name":"Arc Ceramic Table Lamp","description":"A softly curved ceramic lamp for warm desk and bedside lighting.","price":64.0,"salePrice":null,"category":"home","colors":["clay","white"],"materials":["ceramic","linen"],"style":["minimal","warm"],"tags":["lamp","lighting","decor"],"searchTokens":["arc","ceramic","table","lamp","home"],"imageUrls":["https://hual-assets.web.app/products/p017-1.jpg"],"rating":4.7,"reviewCount":91,"inventory":18,"isNew":false,"isSale":false,"createdAt":"2026-05-10T09:00:00Z"}],"fallbackUsed":false,"reason":"preference_vector"}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/visual-search -F "image=@progress/01_API_CONTRACT.yaml" -F "mlKitLabels=shoe"
{"products":[{"id":"p034","name":"Cloudlift Training Sneaker","description":"Lightweight training sneaker with breathable mesh and responsive foam.","price":88.0,"salePrice":74.0,"category":"fitness","colors":["white","silver"],"materials":["mesh","rubber"],"style":["sporty","clean"],"tags":["sneaker","training","sale"],"searchTokens":["cloudlift","training","sneaker","white","fitness"],"imageUrls":["https://hual-assets.web.app/products/p034-1.jpg"],"rating":4.6,"reviewCount":144,"inventory":22,"isNew":false,"isSale":true,"createdAt":"2026-04-22T09:00:00Z"}],"detectedAttributes":{"primaryCategory":"fitness","objectType":"sneaker","colors":["white"],"materials":["mesh"],"style":"sporty"},"matchScores":[0.91],"fallbackMode":false,"queryTokens":["sneaker","white","athletic"]}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/explain-product -H "Content-Type: application/json" --data "{...}"
{"explanationText":"Since you have been browsing warm minimalist decor, this ceramic lamp fits your recent home style signals.","provider":"gemini","cached":false}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/events -H "Content-Type: application/json" --data "{...}"
{"accepted":true,"eventId":"e_20260617_0001"}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/cart/validate -H "Content-Type: application/json" --data "{...}"
{"valid":true,"changes":[]}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/create-payment-intent -H "Content-Type: application/json" --data "{...}"
{"clientSecret":"pi_test_secret_abc","amount":6400,"currency":"usd"}

COMMAND: curl.exe -sS -X POST http://127.0.0.1:8000/orders/confirm -H "Content-Type: application/json" --data "{...}"
{"orderId":"o_001","orderNumber":"HUL-20260617-0007","status":"confirmed"}

COMMAND: curl.exe -sS http://127.0.0.1:8000/orders/u_001
{"orders":[{"orderId":"o_001","orderNumber":"HUL-20260617-0007","items":[{"productId":"p017","variantId":"clay-white","name":"Arc Ceramic Table Lamp","quantity":1,"unitPrice":64.0,"subtotal":64.0}],"total":64.0,"currency":"usd","status":"confirmed","shippingAddress":{"line1":"123 Main St","line2":"Apt 4","city":"Austin","region":"TX","postalCode":"78701","country":"US"},"paymentIntentId":"pi_test_123","createdAt":"2026-06-17T12:10:00Z"}],"count":1}
```

Note: the curl sweep ran inside a PowerShell job so the mock server could be stopped cleanly in the same shell. The endpoint responses above were all HTTP 200.

---
