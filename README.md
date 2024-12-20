#  Recipe Browser

### Steps to Run the App

### Design Notes

- Content View - Collection and Cell
- Model Recipe + Catalog
- Image Cache
- Testing

### Focus Areas: What specific areas of the project did you prioritize? Why did you choose to focus on these areas?

### Time Spent: Approximately how long did you spend working on this project? How did you allocate your time?

- Planning
- Project Setup
- ContentView
  - RecipeView
  - Collection (Catalog) layout
- Basic Model
  - Recipe, Catalog
  - Fetch and Display
- Image Cache
- Project/File Review/Refactor
- Documentation
- Testing
- Bonus - in no particular order
  - Links to recipe, video
  - Share w/ friends
  - Search
  - Device Orientation Layout
  - Tune the Catalog refresh to reuse Images when possible
  - @CachedImage propertyWrapper

### Trade-offs and Decisions: Did you make any significant trade-offs in your approach?

Image loading and caching is the quintessential example for demonstrating challenges integrating background and main thread interactions and testing the use of concurrency. In particular, there are also subtle interactions with the SwiftUI View rendering cycle. If we just rely on a Task wrapper (view modifier) to async load the image we may create a flicker effect because the results of the task aren't yet available for the first render cycle. If the image is already available in our cache, we would like to be able to synchronously "peek" to see and render it immediately if it is available. This can be done in the view `onAppear` for example.

### Weakest Part of the Project: What do you think is the weakest part of your project?

The Image Cache. Concurrency Testing

### Additional Information: Is there anything else we should know? Feel free to share any insights or constraints you encountered.

