import express from 'express'
import { frutasServices } from '../services/frutas.service.js'

export const frutasRouter = express.Router()

frutasRouter.get('/', async (req, res) => {
    const frutas = await frutasServices.getAll()
    return res.send(frutas)
})