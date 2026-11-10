CREATE TABLE bbb_trial_usage (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  reserved_requests integer NOT NULL DEFAULT 0 CHECK (reserved_requests >= 0)
);
INSERT INTO bbb_trial_usage(singleton) VALUES (true);
