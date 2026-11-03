# Secure Profile Completion Flow

This document describes the post-auth "Secure Setup" flow that runs after a user signs up or signs in (Google / Apple / email) when their profile is incomplete.

## Goals
1. Collect a verified phone number (2FA readiness & contact).
2. Capture a display name.
3. Allow optional profile photo upload.
4. Mark profile as completed only after required data + phone verification.

## Route
`/secure-setup` (enumerated in `AppRoute.secureSetup`).

## Entry Conditions
Shown when **any** of these are true:
- Firestore `users/{uid}` document has `profileCompleted != true`.

## Exit Condition
On Finish:
- Firestore document updated with:
  - `name`
  - `phone`
  - `phoneVerified: true` (derived from FirebaseAuth user having a phone number)
  - `photoUrl` (if uploaded)
  - `profileCompleted: true`
  - `updatedAt: serverTimestamp`

## Screen Steps
| Step | Purpose | Skipped If |
|------|---------|------------|
| 0 | Phone entry + send SMS | User already has linked phone (`user.phoneNumber` present) |
| 1 | Enter / verify SMS code | Auto-skip if auto-retrieval succeeds |
| 2 | Profile (name + optional photo) | Never skipped |
| 3 | Review & Finish | Summary & confirm |

If user already has a phone and name, they still see step 2 (can refine name & add photo) then Finish.

## Implementation Notes
- File: `lib/screens/auth/secure_setup_screen.dart`
- Uses `verifyPhoneNumber` with callbacks; links credential via `linkWithCredential` (or signs in with it if already linked provider error occurs).
- Photo stored at `user_photos/<uid>.jpg` in Firebase Storage.
- Firestore merge write ensures idempotence.

## Firestore Fields
```
users/{uid} {
  name: string
  phone: string
  phoneVerified: bool
  photoUrl: string (optional)
  profileCompleted: bool
  updatedAt: serverTimestamp
  createdAt: serverTimestamp (may pre-exist)
}
```

## Future Enhancements (Not Yet Implemented)
- Enforce E.164 formatting and region selection.
- Add resend cooldown UI.
- Integrate reCAPTCHA / safety net status feedback.
- Add multi-factor enrollment (Firebase MFA) once enabled.
- Add analytics events: `secure_setup_step_view`, `secure_setup_complete`.
- Add DOB or consent steps if needed (removed from earlier generic onboarding to streamline).
- Add skip-with-warning for phone (configurable) if business rules change.

## Edge Cases & Resilience
- If verification auto-completes, user jumps straight to profile step.
- If user navigates back or closes app mid-flow, re-entry re-evaluates their current auth+Firestore state and may skip earlier steps.
- If Storage upload fails, photo is simply omitted; user can retry later from a future profile settings screen.

## Migration From Old Onboarding
- Previous `/onboarding` flow still present but no longer navigated to from login or home triggers.
- Consider scheduled removal after ensuring no deep links or legacy references remain.

## QA Checklist
- [ ] New signup -> Secure setup starts at phone step.
- [ ] Google sign-in (no phone) -> phone step appears.
- [ ] User with pre-linked phone -> jumps to profile step.
- [ ] Fail wrong SMS code -> error message.
- [ ] Successful verification -> moves to next step automatically.
- [ ] Photo chosen -> appears in avatar preview & uploaded on Finish.
- [ ] Firestore doc fields match spec; `profileCompleted: true` at end.

_Last updated: 2025-09-28._
