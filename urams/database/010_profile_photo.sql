-- database/010_profile_photo.sql
-- Optional safety migration for teacher/student profile photo upload.
USE urams_db;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS profile_photo VARCHAR(255) NULL AFTER status;
