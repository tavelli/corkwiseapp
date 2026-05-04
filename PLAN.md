## Future Feature: Paste Menu URL

Goal: support importing a wine list from a pasted URL without treating this as generic web scraping.

Core product framing:
- Position this as `Paste menu URL`, not `paste any restaurant URL`.
- Supported targets should be direct PDF menu links first, then supported HTML menu pages later.
- If the link does not contain a readable wine menu, return a clear fallback that tells the user to upload a photo or PDF instead.

Recommended architecture:
1. User pastes a menu URL in the app.
2. App sends the URL to the backend.
3. Backend fetches the URL and inspects the response.
4. Backend decides whether the link is:
   - a direct PDF
   - an HTML page with readable menu text
   - an HTML page linking to a PDF
   - unsupported
5. Backend routes the retrieved content into the same wine-analysis pipeline already used for image/PDF uploads.
6. Backend returns the normal `WineScanResult`.

Why backend-first:
- keeps scraping, redirects, parsing, and bot-protection handling out of the iOS app
- avoids app-side CORS / transport / parsing complexity
- allows provider-specific parsing improvements without shipping an app update

Recommended request shape:
```ts
type AnalyzeWineMenuRequest =
  | {
      inputType: "attachment";
      attachment: {
        base64Data: string;
        mimeType: string;
        filename?: string | null;
      };
      purchaseMode: "glass" | "bottle";
      userPreferences: UserPreferencesPayload;
    }
  | {
      inputType: "url";
      url: string;
      purchaseMode: "glass" | "bottle";
      userPreferences: UserPreferencesPayload;
    };
```

MVP scope:
- support direct PDF URLs only
- support URLs that redirect to PDFs
- reject HTML pages for now with a clear unsupported error

MVP app work:
- add `Paste URL` entry flow
- read from clipboard and/or manual paste
- validate URL client-side
- send URL request to backend
- show loading and clear error states

MVP backend work:
- add `inputType: "url"`
- validate URL
- fetch with timeout and redirect support
- inspect `content-type`
- if PDF:
  - download PDF
  - pass PDF directly to Gemini/OpenAI
- if not PDF:
  - return unsupported for MVP

Phase 2:
- support simple HTML menu pages
- parse readable text from HTML
- detect links to wine PDFs and prefer those
- if enough wine-like content exists, analyze the extracted menu text or derived attachment

Phase 3:
- provider-specific support for common restaurant/menu platforms
- examples: Toast, Resy, BentoBox, SevenRooms, dedicated wine list providers

Useful backend heuristics:
- `content-type: application/pdf`
- URL ends with `.pdf`
- anchor text like `wine list`, `wine menu`, `drinks`, `beverage`
- extracted text contains wine signals:
  - varietals
  - vintages
  - producer names
  - prices

Important failure modes:
- user pastes homepage instead of menu page
- JS-rendered menu with little or no server HTML
- anti-bot / WAF blocks
- image-based menu embedded in HTML
- giant page with too much irrelevant text

Recommended error copy:
- unsupported: `That link didn’t contain a readable wine menu. Try a direct PDF/menu link or upload a screenshot.`
- ambiguous: `We found the site, but not a clear wine list.`

Implementation note:
- direct PDF support is the best first target because both Gemini and OpenAI support PDF input, and it avoids lossy HTML scraping as an MVP.
