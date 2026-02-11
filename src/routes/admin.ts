import { FastifyInstance } from "fastify";
import { supabase } from "../db/supabase";

export async function adminRoutes(app: FastifyInstance) {
  app.post("/admin/approve/:id", async (req: any) => {
    const { id } = req.params;

    await supabase
      .from("payments")
      .update({
        status: "approved",
        approved_at: new Date()
      })
      .eq("id", id);

    return { success: true };
  });
}