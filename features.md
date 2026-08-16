# Features

Living inventory of shipped behavior. Before each commit, check whether your
change touches any feature below and verify the behavior survived.

| ID | Feature | Where | Verified how |
|----|---------|-------|--------------|
| F1 | Story homepage with club explanation + archive link | index.html | Browser check |
| F3 | Boat page: specs, berth layout (2D/4S/1 couch, hot-bunk note), updates feed | boat.html | Browser check |
| F2 | Costs & fees transparency page (amounts null until club votes) | costs.html + cost_items/fee_schedule | Browser check against live DB |
| F1 | Join flow: magic-link sign-in → application → status (pending/member) | join.html | Browser check; RLS enforces one pending app per person |
| —  | Schema v1: membership w/ 2-approval trigger, berth-typed bookings w/ hot-bunk overbook, availability view, RLS everywhere | supabase/migrations/00001,00002 | db push + snapshot |
