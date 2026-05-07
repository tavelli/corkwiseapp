````md
# Corkwise iOS MVP Plan

Corkwise is a personal wine list advisor. The app lets a user scan a restaurant wine list and receive ranked recommendations based on value, producer quality, estimated markup, wine style, user experience level, and whether the user is ordering by the glass or by the bottle.

The MVP should be a native iOS app built with Swift, SwiftUI, SwiftData, Adapty SDK for paywall/purchase gating, Supabase Edge Functions for secure server-side API calls, and OpenAI for wine menu image analysis.

The app does not require user auth.

## Current MVP Scope

### Included

- Native iOS app
- SwiftUI interface
- SwiftData local persistence
- No user accounts/auth
- Onboarding quiz
- Adapty paywall after onboarding
- No free trial and no free scan
- Main scan screen
- Glass/Bottle toggle
- Camera photo scan
- Photo library upload
- Loading state during analysis
- Supabase Edge Function backend
- OpenAI image analysis
- Ranked wine recommendation result page
- Local recent scan history
- Retry flow on failure

### Excluded From MVP

- Auth
- Remote user profiles
- Server-side scan history
- Saved scanned images
- PDF upload
- Menu URL parsing
- OCR preprocessing
- External wine databases
- Meal pairing
- Favorites
- Sharing
- User ratings/feedback loop
- Social features
- Sommelier chat

## Product Positioning

Corkwise should feel like a practical restaurant wine advisor, not a generic scanner.

Core product promise:

> Scan a wine list. Corkwise ranks the smartest picks.

Primary value:

- Helps users avoid overpriced restaurant wine
- Finds unusually good wine-list value
- Explains why a wine is worth ordering
- Adjusts recommendations based on glass vs. bottle
- Adjusts explanations based on user experience level and style preferences

## User Flow

1. User opens app
2. App checks local onboarding state
3. If onboarding is incomplete, show onboarding quiz
4. After onboarding, show Adapty paywall
5. If user purchases successfully, route to main scan screen
6. User selects Glass or Bottle
7. User taps Scan Wine List or Upload Photo
8. User captures/selects a wine menu image
9. App sends image, user preferences, and purchase mode to Supabase Edge Function
10. Supabase securely calls OpenAI
11. OpenAI parses the image and returns structured ranked recommendations
12. App shows loading state while scan is in progress
13. App renders results page
14. App saves scan result locally with SwiftData
15. User can view recent scans later

## Technical Stack

### iOS

- Swift
- SwiftUI
- SwiftData
- PhotosPicker for image library upload
- Camera capture via UIKit bridge or native camera flow
- Adapty SDK for paywall, purchase, restore, and entitlement handling

Adapty supports iOS SDK integration, paywalls, purchases, subscription status, and paywall presentation. Adapty’s iOS docs describe paywall/product concepts and SwiftUI paywall presentation. :contentReference[oaicite:0]{index=0}

### Backend

- Supabase Edge Function
- No Supabase Auth required for MVP
- Public function endpoint is acceptable, but it must include basic request validation and abuse controls
- Store OpenAI API key as Supabase secret/environment variable
- Never expose OpenAI API key in the iOS app

Supabase Edge Functions are appropriate for public HTTP endpoints, small AI inference/orchestration calls, and securely accessing secrets via environment variables. :contentReference[oaicite:1]{index=1}

### AI

- OpenAI API
- Image input sent directly to OpenAI
- No separate OCR layer for MVP
- OpenAI should both parse the wine menu and generate recommendations
- Edge Function should request structured JSON output

## App Navigation

Suggested app-level route states:

```swift
enum AppRoute {
    case onboarding
    case paywall
    case main
}
````

Launch routing logic:

```text
if hasCompletedOnboarding == false:
    show onboarding
else if hasActiveAdaptyEntitlement == false:
    show paywall
else:
    show main app
```

## Onboarding

Onboarding should be short. Do not collect occasion or food pairing in the MVP.

### Quiz Goals

Collect:

* User wine experience level
* Personal wine style preference
* General buying/decision style

### Suggested Questions

#### Question 1

“How would you describe your wine experience?”

Options:

* Beginner
* Casual wine drinker
* Enthusiast

Internal values:

```json
["beginner", "casual", "enthusiast"]
```

#### Question 2

“What kind of wines do you usually like?”

Options:

* Crisp and refreshing
* Fruity and smooth
* Rich and full-bodied
* Earthy and savory
* Bold and structured
* I’m not sure

Internal values:

```json
["crisp_refreshing", "fruity_smooth", "rich_full", "earthy_savory", "bold_structured", "unsure"]
```

Allow one or multiple selections.

#### Question 3

“How do you usually choose wine at a restaurant?”

Options:

* Best value
* Safest crowd-pleaser
* Something interesting
* Premium pick
* I usually need help

Internal values:

```json
["best_value", "safe_choice", "interesting", "premium", "needs_help"]
```

## Paywall

Use Adapty SDK.

Payment model:

* No free trial
* No free scan
* Paywall appears after onboarding
* Main app is gated behind active Adapty entitlement
* Include restore purchases

Suggested paywall copy:

```text
Order wine with more confidence.

Scan a restaurant wine list and get ranked recommendations based on value, producer quality, your taste, and whether you’re ordering by the glass or bottle.
```

CTA:

```text
Continue
```

Restore button:

```text
Restore Purchases
```

## Main Screen

Main screen should be minimal and focused.

### Required UI Elements

* Corkwise app title
* Short positioning line
* Glass/Bottle segmented toggle
* Primary scan button
* Secondary upload photo button
* Recent scans list

### Suggested Layout

```text
Corkwise
Your personal wine list advisor.

[ Glass | Bottle ]

[ Scan Wine List ]

Upload Photo

Recent Scans
- Restaurant name, date, top pick, score
```

### Paste Link Button

The original idea included a paste-link option. For MVP, do not implement menu URL parsing.

Recommendation:

* Hide the paste-link button for MVP
* Do not show disabled UI unless explicitly testing demand
* Add later as v1.1/v1.2

## Glass/Bottle Toggle

The toggle affects recommendation logic only.

It should not affect image parsing.

For example:

* If `purchaseMode = "glass"`, OpenAI should prioritize by-the-glass values and glass pours if visible
* If `purchaseMode = "bottle"`, OpenAI should prioritize bottle values and full-bottle list pricing

Internal enum:

```swift
enum PurchaseMode: String, Codable, CaseIterable {
    case glass
    case bottle
}
```

## Image Input

MVP supports:

* Camera photo
* Photo library image

MVP does not support:

* PDF
* URL
* Multiple pages
* Manual OCR

### Image Preparation

Before upload:

* Resize max dimension to approximately 1600–2200 px
* Compress JPEG around 0.75–0.85 quality
* Preserve enough detail for small menu text
* Do not save image locally after analysis

Suggested service:

```swift
final class ImagePreparationService {
    func prepareForUpload(_ image: UIImage) throws -> Data {
        // Resize image to max dimension
        // JPEG-compress
        // Return Data
    }
}
```

## Loading State

Loading should reinforce the product logic.

Suggested loading messages:

```text
Reading the wine list…
Estimating value…
Comparing producer quality…
Ranking the best picks…
```

Failure should route to a retry screen.

## Results Page

The results page should center on ranked recommendations with a value score.

### Primary Result Structure

1. Hero “Best Pick” card
2. Ranked recommendation list
3. Optional category highlights
4. Notes/caveats

### Scoring Method

Use this scoring definition:

```text
Value score = 1–10 based on estimated retail price vs. menu price, producer reputation, category inflation, age/scarcity, and whether the wine gives the user something meaningfully better than cheaper alternatives on the same list.
```

Important: score is not just markup math.

A wine can score highly because:

* It has unusually low restaurant markup
* It is from a respected producer
* It is aged or scarce
* It is better than cheaper alternatives on the same list
* It is a smart category value
* It represents a rare restaurant buying opportunity

A wine can score poorly because:

* It is generic
* It is heavily marked up
* It is in a category that is commonly inflated
* A nearby cheaper wine is more compelling
* Producer reputation does not justify the price

### Recommendation Card Fields

Each ranked recommendation should show:

* Rank
* Wine name
* Menu price
* Estimated retail price
* Estimated markup
* Value score
* Why
* Fit for user
* Style tags/category tags if useful

Example visual content:

```text
#1
2012 R. Lopez de Heredia Viña Tondonia Rioja

Menu: $88
Est. retail: ~$50–70
Est. markup: ~1.3–1.8x
Value Score: 9.5

Aged, iconic Rioja at a very fair restaurant price. This is probably the smartest bottle on the list.
```

## SwiftData Models

### UserWinePreferences

```swift
import Foundation
import SwiftData

@Model
final class UserWinePreferences {
    var experienceLevel: String
    var preferredStyles: [String]
    var choiceStyle: String
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        experienceLevel: String,
        preferredStyles: [String],
        choiceStyle: String,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.experienceLevel = experienceLevel
        self.preferredStyles = preferredStyles
        self.choiceStyle = choiceStyle
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### WineScan

```swift
import Foundation
import SwiftData

@Model
final class WineScan {
    var createdAt: Date
    var restaurantName: String?
    var purchaseMode: String
    var summaryHeadline: String?
    var resultJSON: String

    init(
        createdAt: Date = .now,
        restaurantName: String? = nil,
        purchaseMode: String,
        summaryHeadline: String? = nil,
        resultJSON: String
    ) {
        self.createdAt = createdAt
        self.restaurantName = restaurantName
        self.purchaseMode = purchaseMode
        self.summaryHeadline = summaryHeadline
        self.resultJSON = resultJSON
    }
}
```

## Codable API Models

### Request

```swift
struct AnalyzeWineMenuRequest: Codable {
    let imageBase64: String
    let purchaseMode: PurchaseMode
    let userPreferences: UserPreferencesPayload
}

struct UserPreferencesPayload: Codable {
    let experienceLevel: String
    let preferredStyles: [String]
    let choiceStyle: String
}
```

### Result

```swift
struct WineScanResult: Codable {
    let restaurantName: String?
    let purchaseMode: String
    let summary: ScanSummary
    let recommendations: [WineRecommendation]
    let categoryHighlights: [CategoryHighlight]
    let notes: [String]
}

struct ScanSummary: Codable {
    let headline: String
}

struct WineRecommendation: Codable, Identifiable {
    var id: String { "\(rank)-\(wineName)" }

    let rank: Int
    let wineName: String
    let displayName: String?
    let extractedText: String?
    let producer: String?
    let region: String?
    let vintage: Int?
    let varietal: String?
    let menuPrice: Double?
    let menuPriceDisplay: String?
    let estimatedRetail: Double?
    let estimatedRetailDisplay: String?
    let estimatedMarkup: Double?
    let estimatedMarkupDisplay: String?
    let valueScore: Double
    let why: String
    let fitForUser: String
    let styleTags: [String]
    let categoryTags: [String]
}

struct CategoryHighlight: Codable {
    let key: String
    let title: String
    let wineRank: Int
}
```

### Failure Response

```swift
struct WineAnalysisErrorResponse: Codable {
    let error: String
    let message: String
    let retrySuggested: Bool
}
```

## Supabase Edge Function

Function name:

```text
analyze-wine-menu
```

Endpoint:

```text
POST /functions/v1/analyze-wine-menu
```

### Request Body

```json
{
  "imageBase64": "...",
  "purchaseMode": "bottle",
  "userPreferences": {
    "experienceLevel": "casual",
    "preferredStyles": ["crisp_refreshing", "earthy_savory"],
    "choiceStyle": "best_value"
  }
}
```

### Successful Response Body

```json
{
  "restaurantName": "Example Bistro",
  "purchaseMode": "bottle",
  "summary": {
    "headline": "Best bottle values on this list"
  },
  "recommendations": [
    {
      "rank": 1,
      "wineName": "Viña Tondonia Rioja",
      "displayName": "R. Lopez de Heredia — Viña Tondonia Rioja",
      "extractedText": "2012 R. Lopez de Heredia Viña Tondonia Rioja $88",
      "producer": "R. Lopez de Heredia",
      "region": "Rioja",
      "vintage": 2012,
      "varietal": null,
      "menuPrice": 88,
      "menuPriceDisplay": "$88",
      "estimatedRetail": 60,
      "estimatedRetailDisplay": "~$60",
      "estimatedMarkup": 1.5,
      "estimatedMarkupDisplay": "~1.5x",
      "valueScore": 9.5,
      "why": "Aged, iconic Rioja at a very fair restaurant price. This is probably the smartest bottle on the list.",
      "fitForUser": "Great for someone who appreciates classic, savory, age-worthy reds.",
      "styleTags": ["red", "savory", "aged", "classic"],
      "categoryTags": ["best_overall", "best_value"]
    },
    {
      "rank": 2,
      "wineName": "Santa Cruz",
      "displayName": "Rhys — Santa Cruz",
      "extractedText": "2019 Rhys Pinot Noir, Santa Cruz $65",
      "producer": "Rhys",
      "region": "Santa Cruz",
      "vintage": 2019,
      "varietal": "Pinot Noir",
      "menuPrice": 65,
      "menuPriceDisplay": "$65",
      "estimatedRetail": 55,
      "estimatedRetailDisplay": "~$55",
      "estimatedMarkup": 1.2,
      "estimatedMarkupDisplay": "~1.2x",
      "valueScore": 9.3,
      "why": "Serious California Pinot from a respected producer at almost retail-adjacent pricing.",
      "fitForUser": "Good fit for someone who likes elegant, nuanced reds.",
      "styleTags": ["red", "pinot_noir", "elegant"],
      "categoryTags": ["crowd_pleaser"]
    }
  ],
  "categoryHighlights": [
    {
      "key": "best_overall",
      "title": "Best Overall",
      "wineRank": 1
    },
    {
      "key": "best_value",
      "title": "Best Value",
      "wineRank": 1
    },
    {
      "key": "crowd_pleaser",
      "title": "Crowd Pleaser",
      "wineRank": 2
    },
    {
      "key": "try_something_new",
      "title": "Try Something New",
      "wineRank": 3
    }
  ],
  "notes": [
    "Some vintages were partially obscured.",
    "Recommendations are based only on the visible menu content."
  ]
}
```

### Failure Responses

Unreadable menu:

```json
{
  "error": "menu_unreadable",
  "message": "The wine list was too blurry or incomplete to analyze.",
  "retrySuggested": true
}
```

No wines detected:

```json
{
  "error": "no_wines_detected",
  "message": "We couldn’t identify enough wine listings to generate recommendations.",
  "retrySuggested": true
}
```

Generic analysis failure:

```json
{
  "error": "analysis_failed",
  "message": "Something went wrong while analyzing the wine list.",
  "retrySuggested": true
}
```

Oversized request:

```json
{
  "error": "image_too_large",
  "message": "The selected image is too large. Please try again with a smaller image.",
  "retrySuggested": true
}
```

## Edge Function Responsibilities

The Supabase Edge Function should:

1. Accept POST requests only
2. Validate request JSON
3. Validate `purchaseMode` is `glass` or `bottle`
4. Validate image exists
5. Enforce approximate payload size limit
6. Read OpenAI API key from environment variable/secret
7. Call OpenAI with image input and structured output requirement
8. Return normalized JSON to the iOS app
9. Return clean user-safe errors
10. Avoid logging image data or sensitive payloads

## Edge Function Environment Variables

Required:

```text
OPENAI_API_KEY
```

Optional:

```text
OPENAI_MODEL
```

Suggested default model should be set server-side, not hardcoded throughout the app.

## OpenAI Prompt Requirements

The OpenAI prompt should instruct the model to return JSON only.

### System/Developer Instruction

```text
You are Corkwise, a personal restaurant wine list advisor.

Analyze the provided restaurant wine list image. Extract visible wines and prices as accurately as possible. Then rank the best recommendations based on value, producer reputation, category pricing, estimated restaurant markup, age/scarcity, and fit for the user's preferences.

Do not invent wines, vintages, prices, restaurants, or producers that are not visible or reasonably inferable from the image. If text is unclear, say so in the notes. If the image is too blurry or does not contain enough wine information, return an error-style result.

The user is ordering by: {{purchaseMode}}.

The purchase mode affects recommendations only. It should not limit extraction. If the user selected glass, prioritize by-the-glass options when visible. If the user selected bottle, prioritize bottle options when visible.

User preferences:
- Experience level: {{experienceLevel}}
- Preferred styles: {{preferredStyles}}
- Choice style: {{choiceStyle}}

Scoring method:
Value score = 1–10 based on estimated retail price vs. menu price, producer reputation, category inflation, age/scarcity, and whether the wine gives the user something meaningfully better than cheaper alternatives on the same list.

The value score is not just markup math. A wine may score well because it has unusually low markup, comes from a respected producer, is aged or scarce, is a smart category value, or meaningfully outperforms cheaper options on the same list.

Usually return 3–5 ranked recommendations. If there are fewer good options, return fewer. Do not rank every wine unless the list is very short.

For each recommendation, include:
- rank
- wine name
- menu price if visible
- estimated retail range
- estimated markup
- value score
- concise explanation
- fit for user
- style tags
- category tags

Return structured JSON only.
```

## Recommended JSON Shape From OpenAI

The Edge Function should validate or coerce the OpenAI response into this shape:

```ts
type WineScanResult = {
  restaurantName: string | null;
  purchaseMode: "glass" | "bottle";
  summary: {
    headline: string;
  };
  recommendations: Array<{
    rank: number;
    wineName: string;
    displayName: string;
    extractedText: string;
    producer: string | null;
    region: string | null;
    vintage: number | null;
    varietal: string | null;
    menuPrice: number | null;
    menuPriceDisplay: string | null;
    estimatedRetail: number | null;
    estimatedRetailDisplay: string | null;
    estimatedMarkup: number | null;
    estimatedMarkupDisplay: string | null;
    valueScore: number;
    why: string;
    fitForUser: string;
    styleTags: string[];
    categoryTags: string[];
  }>;
  categoryHighlights: Array<{
    key: string;
    title: string;
    wineRank: number;
  }>;
  notes: string[];
};
```

## Suggested iOS Project Structure

```text
Corkwise/
  CorkwiseApp.swift

  App/
    AppState.swift
    AppRouter.swift

  Models/
    UserWinePreferences.swift
    WineScan.swift
    PurchaseMode.swift
    WineScanResult.swift

  Services/
    AdaptyService.swift
    EntitlementManager.swift
    WineAnalysisService.swift
    ImagePreparationService.swift

  Features/
    Onboarding/
      OnboardingView.swift
      OnboardingViewModel.swift

    Paywall/
      PaywallView.swift
      PaywallViewModel.swift

    Main/
      MainView.swift
      MainViewModel.swift
      RecentScansView.swift

    Scan/
      CameraPicker.swift
      PhotoPickerView.swift
      ScanLoadingView.swift
      ScanFailureView.swift

    Results/
      ResultsView.swift
      BestPickHeroView.swift
      RecommendationCardView.swift
      CategoryHighlightsView.swift

    Settings/
      PreferencesView.swift
```

## Core Services

### EntitlementManager

Responsibilities:

* Initialize Adapty
* Check active entitlement
* Publish entitlement state
* Restore purchases
* Route app based on entitlement

```swift
final class EntitlementManager: ObservableObject {
    @Published var hasActiveEntitlement: Bool = false
    @Published var isLoading: Bool = true

    func configure() async {
        // Configure Adapty SDK
        // Fetch profile
        // Set hasActiveEntitlement
    }

    func refreshEntitlement() async {
        // Refresh Adapty profile/entitlement
    }

    func restorePurchases() async throws {
        // Restore purchases through Adapty
        // Refresh entitlement
    }
}
```

### WineAnalysisService

Responsibilities:

* Base64-encode prepared image data
* Send request to Supabase Edge Function
* Decode successful result
* Decode clean error response
* Throw app-level errors

```swift
final class WineAnalysisService {
    func analyzeMenu(
        imageData: Data,
        purchaseMode: PurchaseMode,
        preferences: UserWinePreferences
    ) async throws -> WineScanResult {
        // Build request payload
        // POST to Supabase Edge Function
        // Decode WineScanResult
    }
}
```

### ImagePreparationService

Responsibilities:

* Resize image
* Compress image
* Return JPEG data

```swift
final class ImagePreparationService {
    func prepareForUpload(_ image: UIImage) throws -> Data {
        // Resize and compress image
    }
}
```

## Recent Scans

Recent scans should be local only.

Recent scan row should show:

* Restaurant name if available, otherwise “Wine List”
* Date
* Glass/Bottle
* Best pick name
* Best pick score

Example:

```text
Example Bistro
Bottle · Apr 30
Best pick: Viña Tondonia Rioja · 9.5
```

Tapping a recent scan should decode `resultJSON` and open the previous results page.

## Settings / Preferences

MVP should include a simple way to edit wine preferences after onboarding.

Settings should allow editing:

* Experience level
* Preferred styles
* Choice style

Do not require onboarding reset.

## Error Handling

### iOS Error States

Show retry UI for:

* blurry image
* no wines detected
* network failure
* OpenAI/Supabase failure
* oversized image

Suggested failure screen:

```text
Couldn’t read enough of the wine list.

Try taking the photo again in better light, or upload a clearer image.
```

Buttons:

```text
Try Again
Upload Photo
```

### Backend Error Codes

Use:

```text
menu_unreadable
no_wines_detected
image_too_large
invalid_request
analysis_failed
```

## Build Phases

### Phase 1 — App Shell

* Create SwiftUI app
* Add SwiftData container
* Add models
* Add route state
* Build onboarding quiz
* Persist onboarding preferences locally
* Build placeholder main screen

### Phase 2 — Paywall

* Add Adapty SDK
* Configure Adapty
* Add entitlement manager
* Show paywall after onboarding
* Gate main screen behind entitlement
* Add restore purchases

### Phase 3 — Scan Input

* Add Glass/Bottle toggle
* Add camera photo capture
* Add photo library upload
* Add image preparation service
* Add scan loading screen
* Add retry failure screen

### Phase 4 — Supabase Edge Function

* Create `analyze-wine-menu`
* Add `OPENAI_API_KEY` secret
* Validate incoming requests
* Call OpenAI with image and user preference context
* Return structured ranked response
* Return clean failure responses

### Phase 5 — Results UI

* Build best-pick hero card
* Build ranked recommendation cards
* Show menu price, estimated retail, estimated markup, score, and why
* Show category highlights
* Show notes/caveats
* Save result to SwiftData
* Add recent scans list

### Phase 6 — Polish

* Improve loading copy
* Improve error states
* Add preferences editing
* Improve empty state
* Add app icon and launch screen
* Add basic analytics only if desired

## MVP Acceptance Criteria

The MVP is complete when:

1. A new user can complete onboarding
2. A new user sees an Adapty paywall
3. A user without entitlement cannot access scanning
4. A paying user can access main screen
5. User can choose Glass or Bottle
6. User can scan with camera
7. User can upload from photo library
8. App shows loading state during analysis
9. App sends image to Supabase Edge Function
10. Supabase securely calls OpenAI
11. App receives structured ranked recommendations
12. Results page shows best pick and ranked list
13. Each recommendation shows value score, price, estimated retail, estimated markup, and explanation
14. Scan result saves locally
15. Recent scans can be reopened
16. Failure states allow retry

## Guiding Product Principle

Do not overbuild the MVP.

The core test is whether a user will pay to scan a restaurant wine list and receive a useful ranked answer.

Everything else should be deferred unless it directly improves that core loop.

```
::contentReference[oaicite:2]{index=2}
```
