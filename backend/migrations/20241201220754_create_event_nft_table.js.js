/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
export const up = function (knex) {
  return knex.schema.createTable("event_nft", function (table) {
    table.string("event_id").primary();
    table.string("nft").notNullable();
    table.timestamps(true, true);

    // Composite unique constraint
    table.unique(["event_id", "nft"]);
  });
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
export const down = function (knex) {
  return knex.schema.dropTableIfExists("event_rsvps");
};
