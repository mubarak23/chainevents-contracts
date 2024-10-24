import db from "./../config/db.js";

class Event {
  static async create(data) {
    const [event] = await db("events").insert(data);
    return event;
  }

  static async find(id) {
    const event = await db("events").where({ id }).first();
    return event;
  }

  static async search(keyword) {
    const event = await db("events")
      .where("name", "like", "%" + keyword + "%")
      .orWhere("location", "like", "%" + keyword + "%")
      .orWhere("event_id", "like", "%" + keyword + "%")
      .orWhere("event_owner", "like", "%" + keyword + "%");
    return event;
  }

  static async findByEventId(event_id) {
    const event = await db("events").where({ event_id }).first();
    return event;
  }

  static async findByEventOwner(event_owner) {
    const event = await db("events").where({ event_owner });
    return event;
  }

  static async all() {
    const events = await db("events").select("*");
    return events;
  }

  static async paginateData(page = 1, per_page = 10) {
    const offset = (page - 1) * per_page;
    const events = await db("events")
      .select("*")
      .orderBy("created_at", "desc")
      .limit(per_page)
      .offset(offset);

    const total = await db("events").count({ count: "*" }).first();

    return {
      data: events,
      total: total.count,
      current: page,
      pages: Math.ceil(total.count / per_page),
    };
  }

  static async update(id, data) {
    const event = await db("events").where({ id }).update(data);
    return event;
  }

  static async delete(id) {
    const event = await db("events").where({ id }).del();
    return event;
  }
}

export default Event;
