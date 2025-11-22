// index.js

const express = require('express');
const app = express();
const port = 3000;

/**
 * Función central de la aplicación: saluda a un nombre dado.
 * @param {string} name - El nombre a saludar.
 * @returns {string} El mensaje de saludo.
 */
function greet(name) {
    if (!name) {
        return "Hola, mundo!";
    }
    return `Hola, ${name}! Bienvenido a CI/CD.`;
}

// Exporta la función para poder ser probada
module.exports = { greet };


// Ejemplo de uso con Express (la parte que se ejecutaría con npm start)
app.get('/', (req, res) => {
    const greeting = greet(req.query.name);
    res.send(greeting);
});

if (require.main === module) {
    app.listen(port, () => {
        console.log(`Aplicación de ejemplo escuchando en http://localhost:${port}`);
    });
}