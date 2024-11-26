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

  static async registerUser(event_id, user_address) {
    const [registration] = await db("event_registrations").insert({
      event_id,
      user_address,
    });
    return registration;
  }

  static async getRegisteredUsers(event_id) {
    return await db("event_registrations")
      .where({ event_id, is_active: true })
      .select("user_address");
  }

  static async isUserRegistered(event_id, user_address) {
    const registration = await db("event_registrations")
      .where({ event_id, user_address, is_active: true })
      .first();
    return !!registration;
  }

  static async addRSVP(event_id, attendee_address) {
    const [rsvp] = await db("event_rsvps").insert({
      event_id,
      attendee_address,
    });
    return rsvp;
  }

  static async getRSVPs(event_id) {
    return await db("event_rsvps")
      .where({ event_id })
      .select("attendee_address");
  }

  static async hasUserRSVPed(event_id, attendee_address) {
    const rsvp = await db("event_rsvps")
      .where({ event_id, attendee_address })
      .first();
    return !!rsvp;
  }

  static async markAttendance(event_id, user_address) {
    const [attendance] = await db("event_attendance").insert({
      event_id,
      user_address,
    });
    return attendance;
  }

  static async getAttendance(event_id) {
    return await db("event_attendance")
      .where({ event_id })
      .select("user_address");
  }

  static async hasUserAttended(event_id, user_address) {
    const attendance = await db("event_attendance")
      .where({ event_id, user_address })
      .first();
    return !!attendance;
  }

  static async endRegistration(event_id) {
    await db("event_registrations")
      .where({ event_id })
      .update({ is_active: false });
    return true;
  }

  static async getCounts(event_id) {
    const registrations = await db("event_registrations")
      .where({ event_id, is_active: true })
      .count("id as count")
      .first();
    
    const rsvps = await db("event_rsvps")
      .where({ event_id })
      .count("id as count")
      .first();
    
    const attendance = await db("event_attendance")
      .where({ event_id })
      .count("id as count")
      .first();

    return {
      registrations: registrations.count,
      rsvps: rsvps.count,
      attendance: attendance.count
    };
  }
}

export default Event;
