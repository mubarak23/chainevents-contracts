export const up = function (knex) {
  return knex.schema.createTable("events", function (table) {
    table.increments("id").primary();
    table.string("name", 255);
    table.string("event_id", 255);
    table.string("location", 255);
    table.string("event_owner", 255);
    table.timestamps(true, true);
  });
};

export const down = function (knex) {
  return knex.schema.dropTableIfExists("events");
};
