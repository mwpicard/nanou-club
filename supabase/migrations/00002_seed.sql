-- Seed: Nanou's home harbour and the cost-transparency skeleton.
-- Amounts stay null until the club votes — the site shows the categories.

insert into harbours (name, country, lat, lon, description) values
  ('Port de Masnou', 'Spain', 41.4772, 2.3163,
   'Nanou''s home harbour, just up the coast from Barcelona. Where the resurgence begins.');

insert into cost_items (name, category, period, notes) values
  ('Mooring, Port de Masnou',        'mooring',     'monthly', 'Home berth'),
  ('Hull & liability insurance',     'insurance',   'annual',  null),
  ('Paid crew / boat keeper',        'crew',        'monthly', 'Professional crew who maintain and sail her'),
  ('Maintenance & recommissioning',  'maintenance', 'one_off', 'New mainsail, electrics, bow thruster under study'),
  ('Fuel & consumables',             'fuel',        'monthly', 'Perkins M130; 1,800 nm range'),
  ('Club administration',            'admin',       'annual',  'Domain, hosting, registrations');

insert into fee_schedule (name, period, notes) values
  ('Club membership',        'monthly',   'Amount to be decided by club vote'),
  ('Voyage leg contribution','per_leg',   'Amount to be decided by club vote'),
  ('Harbour live-aboard',    'per_night', 'Amount to be decided by club vote');
