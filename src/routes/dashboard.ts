import { FastifyInstance } from "fastify";
import { supabase } from "../db/supabase";

export async function dashboardRoutes(app: FastifyInstance) {
  app.get("/dashboard/:employeeId", async (req: any) => {
    const { employeeId } = req.params;

    const { data: earnings } = await supabase
      .from("earnings")
      .select("amount");

    const { data: payments } = await supabase
      .from("payments")
      .select("amount")
      .eq("status", "approved")
      .eq("employee_id", employeeId);

    const totalPayments =
      payments?.reduce((sum, p) => sum + Number(p.amount), 0) || 0;

    return {
      totalPayments
    };
  });
}