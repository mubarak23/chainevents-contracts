/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
export const seed = async function (knex) {
  // Clear existing entries
  await knex("event_rsvps").del();
  await knex("event_registrations").del();
  await knex("event_attendance").del();
  await knex("events").del();

  // Insert events
  const events = Array.from({ length: 5 }, (v, i) => ({
    id: i + 1,
    name: `Event ${i + 1}`,
    event_id: `event_${String(i + 1).padStart(3, "0")}`,
    location: `Location ${i + 1}`,
    event_owner: `Owner ${i + 1}`,
  }));
  await knex("events").insert(events);

  // Insert event_attendance
  const eventAttendance = Array.from({ length: 5 }, (v, i) => [
    {
      id: i * 2 + 1,
      event_id: `event_${String(i + 1).padStart(3, "0")}`,
      user_address: `user_${i * 2 + 1}`,
    },
    {
      id: i * 2 + 2,
      event_id: `event_${String(i + 1).padStart(3, "0")}`,
      user_address: `user_${i * 2 + 2}`,
    },
  ]).flat();
  await knex("event_attendance").insert(eventAttendance);

  // Insert event_registrations
  const eventRegistrations = Array.from({ length: 5 }, (v, i) => [
    {
      id: i * 2 + 1,
      event_id: `event_${String(i + 1).padStart(3, "0")}`,
      user_address: `user_${i * 2 + 3}`,
      is_active: true,
    },
    {
      id: i * 2 + 2,
      event_id: `event_${String(i + 1).padStart(3, "0")}`,
      user_address: `user_${i * 2 + 4}`,
      is_active: i % 2 === 0,
    },
  ]).flat();
  await knex("event_registrations").insert(eventRegistrations);

  // Insert event_rsvps
  const eventRsvps = Array.from({ length: 5 }, (v, i) => [
    {
      id: i * 2 + 1,
      event_id: `event_${String(i + 1).padStart(3, "0")}`,
      attendee_address: `user_${i * 2 + 5}`,
    },
    {
      id: i * 2 + 2,
      event_id: `event_${String(i + 1).padStart(3, "0")}`,
      attendee_address: `user_${i * 2 + 6}`,
    },
  ]).flat();
  await knex("event_rsvps").insert(eventRsvps);
};
