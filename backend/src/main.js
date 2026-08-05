import express from 'express'
import cors from 'cors'
import { frutasRouter } from './routes/frutas.routes.js'

const app = express()

app.use(cors())

app.get('/', (req, res) => {
    return res.send("Hola Mundo")
})

app.use('/frutas', frutasRouter)

app.listen(3000, () => {
    console.log(`API Rodando em: http://localhost:3000`);

})