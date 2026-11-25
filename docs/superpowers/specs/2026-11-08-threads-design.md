# Threads SwiftUI

Build an iPhone application from the supplied Figma kit, page 12:5114 in file FataKGiATSCr6NXFAbJWdn. The user confirmed a local version without a server or sign-in.

Match the dark Russian interface, supplied images, typography, spacing, drawer, and floating dock. Main destinations: home, messages, composer sheet, activity, profile and settings. Additional flows: search, following, liked, saved and disappearing feeds, reorder/create feeds, edit profile and local conversations. Transient loading references resolve to useful content or empty states.

Implementation decisions: SwiftUI, iOS 17+, no external packages, a shared observable store and Codable persistence in UserDefaults. Use native keyboard, status bar, navigation and scrolling. Per the user's follow-up, use the native iOS TabView with five items and system Liquid Glass on iOS 26+, keeping compose in the middle as a sheet action. Photos selected by the user remain local. Text posts are limited to 500 characters. No remote service is simulated as a real account.

The app must compile, launch, and preserve local changes. Verify store behavior with tests and visible flows in the simulator. Document launch instructions and local scope in README.
