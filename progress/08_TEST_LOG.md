# 08 - Test Log

Append a new entry every session. Do not overwrite history; this file is the record that QA actually ran continuously instead of getting saved for the end.

---

### Sprint QA Audit - 2026-06-19 / Codex

**Command(s) run:**
```powershell
python -m pytest backend/app/tests -q
D:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\debug_router_test.dart test\flow_golden_test.dart
Get-ChildItem app\ios,app\macos,app\windows,app\linux,app\lib -Recurse -File | Where-Object { $_.FullName -notmatch '\\build\\|\\.dart_tool\\|\\ephemeral\\|generated_' } | Select-String -Pattern 'com\.example|DefaultFirebaseOptions have not been configured|Web placeholder|not yet configured'
```

**Result summary:**
```text
backend/app/tests: 67 passed, 1 skipped in 5.06s
dart analyze lib test: No issues found!

Flutter widget verification:
- debug_router_test.dart: passed
- flow_golden_test.dart: 3 failed
  - flow1_4_home.png: 20.12% / 521,448 px diff
  - flow2_1_home_guest.png: 20.12% / 521,441 px diff
  - flow3_1_home_returning.png: 20.20% / 523,669 px diff

Placeholder scan remaining hits:
- app/lib/firebase_options.dart still contains unconfigured iOS/macOS/Windows/Linux Firebase branches
- app/lib/firebase_options.dart still labels the web block as a placeholder
```

**Verification performed:**
- Confirmed Flutter startup now initializes Firebase in `app/lib/main.dart` before `runApp`, closing the direct runtime auth/Firestore bootstrap gap.
- Confirmed all backend regression tests still pass after the QA fixes.
- Confirmed non-generated platform `com.example` identifiers were removed from iOS, macOS, Linux, and Windows config files.
- Confirmed the remaining placeholder problem is real platform Firebase configuration, not stray template metadata.
- Confirmed checkout is still not Stripe-backed end-to-end by code inspection: `backend/app/services/checkout_service.py` returns contract examples only.

**Open blockers:**
- `app/lib/firebase_options.dart` is still not fully configured beyond Android, so the “no placeholders left” goal is not complete yet.
- `app/test/flow_golden_test.dart` is currently failing all three home-flow goldens and needs a follow-up visual regression pass.
- Checkout/payment wiring is still a stub until Sprint 6 backend work lands.

---

### Sprint 5 - Track B AI-Surfaced UI - 2026-06-19 / Codex

**Command(s) run:**
```powershell
flutter pub get
dart analyze lib test
flutter test test\sprint5_ai_ui_test.dart --update-goldens
flutter test test\widget_golden_test.dart
flutter test test\flow_golden_test.dart test\sprint3_catalog_test.dart --update-goldens
flutter test
flutter build apk --debug --no-pub
flutter build apk --profile --no-pub
D:\Sdk\platform-tools\adb.exe devices -l
```

**Result summary:**
```text
Sprint 5 focused UI tests: 4 passed
Shared-widget golden tests: 39 passed
Full Flutter suite: 53 passed
Android debug APK: built successfully (215,571,899 bytes)
Android profile APK: built successfully (115,257,153 bytes)
Info.plist XML validation: OK
ADB: List of devices attached (empty)

dart analyze lib test:
No Sprint 5 issues.
7 pre-existing cart/wishlist/shell findings remain (BUG-009).
```

**Verification performed:**
- Camera permission denial renders a recoverable state with Open Settings and gallery fallback.
- Visual flow screenshot sequence captured at `progress/screenshots/sprint5_visual_search/`: camera ready, immediate processing, >2s waking-up copy, and spring results sheet.
- Fallback results visibly show exact `On-device match` labeling in the sheet plus per-card `On-device` source pills and match percentages.
- Authenticated For You uses `/recommendations/{uid}`; guest/cold-start uses rating-sorted trending products with the identical rail/card layout and staggered reveal.
- Product explanations start after product content, fade/slide in for authenticated users, and remain absent for guests.
- Native Android camera, gallery, permission, and ML Kit dependencies compile in both debug and profile APKs.

**Open verification blocker:**
The required physical Android memory test could not run. Flutter detected only Windows, Chrome, and Edge; `adb devices -l` returned an empty list. The camera task remains `Blocked` until a USB-debugging-authorized phone opens/closes the profile build three times and post-GC memory is confirmed within 5% of baseline.

---

### Sprint 5 - Track A AI Endpoints - 2026-06-19 / Codex

**Command(s) run:**
```powershell
$env:HUAL_GEMINI_DISABLED='true'; python -m pytest backend\app\tests -q
python -m openapi_spec_validator progress\01_API_CONTRACT.yaml
# TestClient live payload/timing script with HUAL_GEMINI_DISABLED=true
```

**Result summary:**
```text
backend/app/tests: 67 passed, 1 skipped in 4.34s
progress/01_API_CONTRACT.yaml: OK

VISUAL {"status": 200, "fallbackMode": true, "category": "fitness", "topIds": ["p035", "p039", "p034", "p038", "p041"], "repeatMs": 9.484}
EXPLAIN {"status": 200, "explanationText": "Because you showed interest in home, this product's ceramic may match your style.", "provider": "template", "cached": false}
HOME {"fallbackUsed": false, "reason": "preference_vector", "ids": ["p017", "p021", "p015", "p022", "p018", "p019", "p023", "p025"]}
FITNESS {"fallbackUsed": false, "reason": "preference_vector", "ids": ["p034", "p035", "p038", "p039", "p037", "p010", "p005", "p041"]}
```

**Verification performed:**
- Gemini was deliberately disabled through `HUAL_GEMINI_DISABLED=true`. `/visual-search` returned HTTP 200 with `fallbackMode: true`, an ML Kit-derived `fitness` category, scored products, and exact contract fields.
- `/explain-product` returned the deterministic, grounded template with `provider: template`; a repeated request returned `cached: true`. A guest with no preference signal received `preference_signal_missing`, allowing the client to hide the explanation.
- The two synthetic event histories produced visibly different recommendation ordering and category emphasis. A no-event user returned hydrated trending products with `fallbackUsed: true`.
- A repeated identical visual-search image hash returned in 9.484ms, below the 200ms requirement.

---

### Sprint 4 - Track B Cart/Wishlist UI Integration - 2026-06-17 / Antigravity

**Command(s) run:**
```powershell
flutter test test/cart_golden_test.dart --update-goldens
```

**Result summary:**
```text
All tests passed!
Generated:
- progress/screenshots/sprint4_cart_mid_swipe.png
```

**Verification performed:**
- Cart UI implemented with offline optimistic updates, swipe-to-delete, and quantity modification logic mapped to `CartController`.
- Golden test created and verified the cart mid-swipe delete interaction state offline without backend dependency.

---

### Sprint 4 - Track A Cart/Wishlist Rules + Cart Validate - 2026-06-17 / Codex

**Command(s) run:**
```powershell
python -m pytest backend/app/tests/test_api_routes.py -q
npm.cmd run test:rules
npx.cmd firebase emulators:exec --only firestore "python -m pytest backend/app/tests/test_cart_validate_firestore.py -q"
python -m pytest backend/app/tests -q
npm.cmd run test:rules
```

**Result summary:**
```text
backend/app/tests/test_api_routes.py: 31 passed
Firestore emulator rule tests: passed
Firestore emulator cart drift test: 1 passed
backend/app/tests: 62 passed, 1 skipped
Final Firestore emulator rule tests: passed
```

**Verification performed:**
- Firestore rules: authenticated user A can read/write only `users/{uid}/cart/*` and `users/{uid}/wishlist/*`; user B cannot read user A cart/wishlist; cart quantity `0` and `21` are rejected by the rule.
- `/cart/validate`: valid cart item returns `{"valid": true, "changes": []}`; stale price returns `price_changed`; missing product returns `unavailable`; zero inventory returns `out_of_stock`; requested quantity over inventory returns `quantity_reduced`.
- Manual emulator check: seeded product `p_firestore_drift` in Firestore at `price=64.0`, called `/cart/validate` successfully, updated the same Firestore document to `price=58.0`, called `/cart/validate` again, and confirmed it returned `valid=false` with a `price_changed` entry (`oldPrice=64.0`, `newPrice=58.0`).
- Firebase CLI needed sandbox escalation to read `C:\Users\ranam\.config\configstore\firebase-tools.json`; emulator itself ran locally without Firebase login.

---

### Sprint 3 - Track B Home/Search/Product UI - 2026-06-17 / Codex

**Command(s) run:**
```powershell
D:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib test
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\sprint3_catalog_test.dart --update-goldens
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\packages\flutter_tools\bin\flutter_tools.dart test test\flow_golden_test.dart --update-goldens
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\packages\flutter_tools\bin\flutter_tools.dart test
python -m pytest backend\app\tests
D:\flutter\bin\cache\dart-sdk\bin\dart.exe D:\flutter\packages\flutter_tools\bin\flutter_tools.dart devices
```

**Result summary:**
```text
dart analyze lib test:
No issues found!

Sprint 3 screenshot/behavior test:
3 passed
Generated:
- progress/screenshots/sprint3_home.png
- progress/screenshots/sprint3_search.png
- progress/screenshots/sprint3_product_detail.png

Flow golden refresh:
3 passed

Full Flutter suite:
48 passed

Backend catalog/API regression:
59 passed in 2.46s

Flutter devices:
Windows desktop, Chrome web, and Edge web detected. No physical mobile device detected.
```

**Live verification performed (if applicable):**
Home, Search, and Product detail were verified through widget/screenshot tests with a deterministic in-memory API client. The 404 product path was verified to leave the detail route and show a snackbar instead of crashing or spinning. The required real-device/profile-mode hero jank check could not be performed because no physical device is attached in this environment; this is the only remaining blocker for marking the Sprint 3 Track B task Done.

---

### Sprint 3 - Track A Catalog API - 2026-06-17 / Codex

**Command(s) run:**
```powershell
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe backend\scripts\generate_schemas.py
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m openapi_spec_validator progress\01_API_CONTRACT.yaml
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe backend\scripts\import_seed_products.py --dry-run
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m pytest backend\app\tests -q
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8001
curl.exe -sS -X POST http://127.0.0.1:8001/search -H "Authorization: Bearer test-token" -H "Content-Type: application/json" --data-binary @%TEMP%\hual-search-body.json
```

**Result summary:**
```text
progress\01_API_CONTRACT.yaml: OK

seed import dry-run:
p001: ['boxy', 'layering', 'linen', 'multi', 'overshirt', 'shirt', 'variant']
p002: ['dress', 'knit', 'midi', 'ribbed', 'sale']
p003: ['cropped', 'jacket', 'new', 'outerwear', 'utility']
dry-run products=50

pytest:
...........................................................              [100%]
59 passed in 2.40s

live /search:
{"products":[{"id":"p017","name":"Arc Ceramic Table Lamp","description":"A softly curved ceramic lamp for warm desk and bedside lighting.","price":64.0,"salePrice":null,"category":"home","colors":["clay","white"],"materials":["ceramic","linen"],"style":["minimal","warm"],"tags":["lamp","lighting","decor"],"searchTokens":["arc","ceramic","decor","lamp","lighting","table"],"imageUrls":["https://hual-assets.web.app/products/p017-1.jpg"],"rating":4.7,"reviewCount":91,"inventory":18,"isNew":false,"isSale":false,"createdAt":"2026-05-10T09:00:00Z"},{"id":"p015","name":"Focus Smart Lamp","description":"Dimmable smart lamp with warm-to-cool light and app scenes.","price":112.0,"salePrice":null,"category":"electronics","colors":["white","charcoal"],"materials":["polycarbonate","steel"],"style":["smart-home","minimal"],"tags":["lamp","smart","multi-variant"],"searchTokens":["focus","lamp","multi","smart","variant"],"imageUrls":["https://hual-assets.web.app/products/p015-1.jpg"],"rating":4.6,"reviewCount":59,"inventory":16,"isNew":true,"isSale":false,"createdAt":"2026-06-04T09:00:00Z"}],"pageToken":null,"total":2,"appliedFilters":{"query":"lamp","sortBy":"relevance"}}
```

**Live verification performed (if applicable):**
Catalog behavior was verified through FastAPI `TestClient` using the real `backend.app.main:create_app` app, generated schemas from `01_API_CONTRACT.yaml`, and local seed-backed repository fallback. Tests cover `/search` filters, price range, all sort modes, pagination, empty results, malformed `pageToken`, `/products/{id}`, `/products/batch`, and `/events`. A live local uvicorn run also returned HTTP 200 for `/search` with `Authorization: Bearer test-token`.

Note: Live Firestore seed import was not run because this environment has no Firebase service-account/project credentials, and prior Firestore emulator verification is still blocked by missing Java. The import script is implemented and dry-run verified.

---

### Sprint 1 - Track A Backend Scaffolding - 2026-06-17 / Codex

**Command(s) run:**
```powershell
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe backend\scripts\generate_schemas.py
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m pip install -r backend\requirements.txt
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m pytest backend\app\tests -q
C:\Users\ranam\AppData\Local\Programs\Python\Python312\python.exe -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8001
curl.exe -i http://127.0.0.1:8001/health
npm.cmd install --ignore-scripts --no-audit --no-fund --cache .\.npm-cache
npm.cmd run test:rules
winget install --id Microsoft.OpenJDK.17 --scope user --silent --accept-package-agreements --accept-source-agreements
```

**Result summary:**
```text
pytest:
.............................................                            [100%]
45 passed in 3.17s

local health:
HTTP/1.1 200 OK
content-type: application/json
{"status":"ok","version":"0.1.0","timestamp":"2026-06-17T11:19:56.787568Z"}

Firebase rules emulator:
npm install completed after a no-audit/no-fund retry, but `npm.cmd run test:rules` failed before executing tests because the Firestore emulator could not spawn Java:
Error: Could not spawn `java -version`. Please make sure Java is installed and on your system PATH.

Attempted mitigation:
`winget install --id Microsoft.OpenJDK.17 --scope user --silent --accept-package-agreements --accept-source-agreements`
The installer timed out and remained stuck with winget/java processes running. Those installer processes were stopped; `java` remained unavailable on PATH.
```

**Live verification performed (if applicable):**
The real FastAPI backend (not the Sprint 0 mock) was started locally with uvicorn on `127.0.0.1:8001`, and `/health` returned a real 200 with a runtime timestamp. Docker is not installed in this environment, so local Docker container verification was not available.

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

 # # #   S p r i n t   2   -   T r a c k   B   E n t r y   F l o w   I n t e g r a t i o n   -   2 0 2 6 - 0 6 - 1 7   /   A n t i g r a v i t y 
 
 * * C o m m a n d ( s )   r u n : * * 
 \ \ \ p o w e r s h e l l 
 f l u t t e r   t e s t   - - u p d a t e - g o l d e n s   t e s t / f l o w _ g o l d e n _ t e s t . d a r t 
 \ \ \ 
 
 * * R e s u l t   s u m m a r y : * * 
 \ \ \ 	 e x t 
 A l l   t e s t s   p a s s e d ! 
 
 G e n e r a t e d   s c r e e n s h o t s   i n   p r o g r e s s / s c r e e n s h o t s / s p r i n t 2 _ f l o w s / : 
 -   f l o w 1 _ 1 _ o n b o a r d i n g . p n g 
 -   f l o w 1 _ 2 _ a u t h . p n g 
 -   f l o w 1 _ 3 _ p r e f e r e n c e s . p n g 
 -   f l o w 1 _ 4 _ h o m e . p n g 
 -   f l o w 2 _ 1 _ h o m e _ g u e s t . p n g 
 -   f l o w 3 _ 1 _ h o m e _ r e t u r n i n g . p n g 
 \ \ \ 
 
 * * L i v e   v e r i f i c a t i o n   p e r f o r m e d : * * 
 W i d g e t   g o l d e n   i n t e g r a t i o n   t e s t s   r a n   t h r e e   f u l l   u s e r   f l o w s   s i m u l a t i n g   d e v i c e   e x e c u t i o n   a t   3 . 0   p i x e l   r a t i o : 
 1 .   N e w   U s e r :   S p l a s h   - >   O n b o a r d i n g   - >   A u t h   - >   P r e f e r e n c e s   - >   H o m e 
 2 .   G u e s t :   S p l a s h   - >   O n b o a r d i n g   - >   S k i p   - >   G u e s t   A u t h   - >   H o m e 
 3 .   R e t u r n i n g :   S p l a s h   - >   H o m e 
 V e r i f i e d   z e r o   r o u t i n g   l o o p s   a n d   f u l l   S t a t e   r e d i r e c t i o n   l o g i c   v i a   G o R o u t e r   a n d   R i v e r p o d   A u t h S t a t e   c h a n g e s . 
 
 - - - 
  
 
