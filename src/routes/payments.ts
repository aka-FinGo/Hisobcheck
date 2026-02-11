import { FastifyInstance } from "fastify";
import { supabase } from "../db/supabase";

export async function paymentRoutes(app: FastifyInstance) {
  app.post("/payments", async (req: any, reply) => {
    const { employee_id, amount, currency, description, created_by } = req.body;

    const { data: settings } = await supabase
      .from("system_settings")
      .select("*")
      .single();

    let status = "pending";

    if (amount <= settings.auto_approve_limit) {
      status = "approved";
    }

    const { data } = await supabase.from("payments").insert([
      {
        employee_id,
        amount,
        currency,
        description,
        created_by,
        status
      }
    ]);

    return { success: true };
  });
}
