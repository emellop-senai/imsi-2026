import { useEffect, useState } from 'react'
import FutaComponent from './components/frutaComponent'
import './App.css'

function App() {
  const [frutas, setFruta] = useState([])

  async function getFrutas() {
    try {
      const res = await fetch("http://localhost:3000/frutas")
      const data = await res.json()
      setFruta(data)
    } catch (error) {
      console.error("Failed to fetch frutas:", error)
    }
  }

  useEffect(() => {
    getFrutas()
  }, [])

  return (
    <div >
      <img src="" alt="" />
      teste
      {
        frutas ? frutas.map((fruta) => (<FutaComponent data={fruta} />)) : <div>...carregando</div>
      }
    </div>
  )
}

export default App