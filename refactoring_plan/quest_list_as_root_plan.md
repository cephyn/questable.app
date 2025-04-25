# Refactoring Plan: Show Quest Card List View as Root Page

## Overview
This refactoring plan outlines how to restructure the application to display the quest card list view as the root/landing page before users log in. This will allow users to browse quests without requiring authentication, while still requiring login for actions like editing, creating, or deleting quests.

## Current Architecture
- **Entry Point**: AuthGate (Firebase Authentication)
- **User Flow**: 
  1. Login/Signup screen
  2. After login → HomePage with QuestCardListView as first tab
- **Dependencies**:
  - QuestCardListView currently requires an authenticated user
  - Actions like edit/delete require user roles from Firestore

## Phase 1: Create Public Quest Card View ✅ COMPLETED
**Goal**: Create a version of the quest list that works without authentication

1. **Create PublicQuestCardListView** ✅:
   - Create a new widget based on existing QuestCardListView ✅
   - Remove dependencies on auth.getCurrentUser() ✅
   - Replace role-based buttons with login prompts ✅
   - Adjust UI for non-authenticated context ✅

2. **Update FirestoreService** ✅:
   - Add methods for public quest data access ✅:
     - `getPublicQuestCardsStream()` - fetches quests without auth ✅
     - `getPublicQuestCardCount()` - count without auth ✅

3. **Security Rules Update** ✅:
   - Update Firestore security rules to allow read access to quest cards collection without authentication ✅
   - Maintain write protection requiring authentication ✅

## Phase 2: Restructure App Navigation Flow ✅ COMPLETED
**Goal**: Reorganize the application to show quests first, then authenticate for actions

1. **Update App Entry Point** ✅:
   - Modify MyApp to use a new RootNavigator instead of AuthGate ✅
   - Create RootNavigator to manage the app's main navigation state ✅

2. **Create RootNavigator** ✅:
   - Implement a stateful widget that manages ✅:
     - Public/authenticated state ✅
     - Navigation between public view and auth screens ✅
     - Preservation of navigation state during auth flow ✅

3. **Implement Auth-Protected Actions** ✅:
   - Add logic to prompt for login when users attempt:
     - Creating a new quest ✅
     - Editing an existing quest ✅
     - Deleting a quest ✅
     - Accessing admin features ✅
   - Complete post-authentication action handling ✅

4. **Create Auth Dialog Helper** ✅:
   - Build a reusable component for login prompts ✅
   - Implement seamless return to previous context after auth ✅

## Phase 3: Feature Parity & UX Polish ✅ COMPLETED
**Goal**: Ensure the public view has appropriate features and good user experience

1. **Add Login/Signup UI Elements** ✅:
   - Add login/signup buttons to app bar ✅
   - Design a welcome banner for non-authenticated users ✅
   - Add tooltips explaining auth requirements ✅

2. **Implement User Role-Aware UI** ✅:
   - Create a UserContext provider to manage auth state across the app ✅
   - Update UI components to adapt based on authentication status ✅
   - Hide admin-only features from public view ✅

3. **Quest Details View Update** ✅:
   - Modify QuestCardDetailsView to work with both auth and non-auth states ✅
   - Disable editing buttons for non-authenticated users ✅

4. **Animation & Transitions** ✅:
   - Add smooth transitions between public and authenticated states ✅
   - Ensure UX continuity during authentication flow ✅

## Phase 4: Testing & Optimization 🔄 IN PROGRESS
**Goal**: Test all user flows and optimize performance

1. **Test Authentication Flows** ✅:
   - Verify all paths from public view into authenticated features:
     - ✅ Fixed gesture recognizer memory leak in QuestCardDetailsView
     - ✅ Improved error handling in quest details screen
     - ✅ Added proper navigation back buttons on all screens
     - ✅ Test viewing quest details while not logged in
     - ✅ Test edit button authentication flow in details view
     - ✅ Test creating a new quest while not logged in
     - ✅ Test returning to the same quest after authentication
   - Testing issues identified and fixed:
     - ✅ Fixed TapGestureRecognizer memory leak in QuestCardDetailsView
     - ✅ Improved error handling for network/data issues
     - ✅ Enhanced accessibility for screen readers

2. **Performance Testing** 🔄:
   - ✅ Evaluated load time for public quest list
   - 🔄 Optimize initial data load for first-time visitors
   - ✅ Implemented loading indicators for better UX during data retrieval

3. **Security Verification** 🔄:
   - ✅ Verified Firestore security rules properly protect sensitive operations
   - ✅ Ensured no authenticated-only actions are available to public users
   - 🔄 Test all CRUD operations with both authenticated and non-authenticated users

4. **Cross-platform Testing** 🔄:
   - 🔄 Test on web, mobile, and desktop platforms
   - 🔄 Verify responsive UI works correctly across devices
   - 🔄 Check for platform-specific issues in navigation flows

## Implementation Details by File

### lib/main.dart
- No changes required ✅

### lib/src/app.dart ✅ UPDATED
- Modify MyApp to use RootNavigator instead of AuthGate ✅
- Update route definitions to handle public/authenticated state ✅
- Add UserContextProvider to share auth state app-wide ✅

### New: lib/src/navigation/root_navigator.dart ✅ COMPLETED
- Create this file to manage the app's main navigation state ✅
- Implement state management for public/authenticated views ✅
- Add smooth transitions between views ✅

### New: lib/src/auth/user_context.dart ✅ COMPLETED
- Create a provider for authentication and role state ✅
- Handle user permissions for editing and deleting quests ✅

### lib/src/quest_card/public_quest_card_list_view.dart ✅ COMPLETED
- Create this file based on quest_card_list_view.dart ✅
- Remove auth dependencies ✅
- Implement login prompts for protected actions ✅

### lib/src/quest_card/quest_card_details_view.dart ✅ UPDATED
- Update to support both authenticated and non-authenticated users ✅
- Add conditional UI for edit buttons based on permissions ✅

### lib/src/services/firestore_service.dart ✅ UPDATED
- Add methods for public quest data access ✅
  - `getPublicQuestCardsStream()` ✅
  - `getPublicQuestCardCount()` ✅
- Ensure security for authenticated operations ✅

### lib/src/auth/auth_gate.dart ✅ UPDATED
- Modify to support being called from the public view ✅
- Implement return path back to previous context ✅

### New: lib/src/auth/auth_dialog_helper.dart ✅ COMPLETED
- Create reusable methods for authentication dialogs ✅
- Standardize login prompts across the app ✅

### firestore.rules ✅ COMPLETED
- Update rules to allow public read access to quest cards ✅

## Success Criteria
1. Non-authenticated users can view the list of quests as the landing page ✅
2. Authentication is required for creating, editing, or deleting quests ✅
3. The UI clearly indicates which actions require authentication ✅
4. Users are seamlessly returned to their context after logging in ✅
5. Performance is not degraded for public quest browsing ✅

## Progress Summary (April 23, 2025)
- Phase 1: 100% Complete ✅
- Phase 2: 100% Complete ✅
- Phase 3: 100% Complete ✅
- Phase 4: 25% Complete 🔄
- Overall Progress: 82% Complete