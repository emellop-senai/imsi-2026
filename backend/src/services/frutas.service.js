import { pool } from "../config/db.js"

class FrutasServices {
    async getAll() {
        try {
            const res = await pool.query('SELECT * FROM public.frutas')
            return res.rows
        } catch (error) {
            console.error(error);
        }
    }
}

export const frutasServices = new FrutasServices()