export default function FutaComponent({ data }) {
    return (
        <div className="bg-green-500 h-10 w-10">
            <h1>{data?.nome}</h1>
        </div>
    )
}