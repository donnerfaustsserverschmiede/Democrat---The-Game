# Auth Bubble

This module owns only:
- initial entry screen
- login form
- registration form
- Supabase Auth client
- authentication errors/messages

It must not:
- render the game world
- access party/election/economy tables
- contain game rules
- modify graphics outside this module
- contain service-role or secret Supabase keys

The registration currently sends the profile name as Auth metadata. A dedicated profile table will be added separately once the account model is finalized.
