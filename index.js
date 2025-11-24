// index.js

const express = require('express');
const _ = require('lodash'); // Nueva dependencia
const app = express();
const port = 3000;

// 💡 CLAVE: Registra el momento en que la aplicación inicia.
/**
const startTime = Date.now();
const errorDelaySeconds = 120; // 2 minutos
*/

/**
 * Calculates a complex, synthetic metric (slow operation).
 * This function is intentionally designed to be CPU-bound for testing CI duration.
 * @param {number} iterations - Number of iterations for the inner loop.
 * @returns {number} A calculated sum.
 */
function calculateHeavyMetric(iterations) {
    let sum = 0;
    // Bucle diseñado para consumir tiempo de CPU de forma síncrona
    for (let i = 0; i < iterations; i++) {
        let subResult = 1;
        // Bucle interno para aumentar la carga de trabajo
        for (let j = 0; j < 5000; j++) {
            subResult = (subResult * 1.0000001) + 1;
        }
        sum += subResult;
    }
    return sum;
}

/**
 * Función que simula la preparación y manipulación de datos usando Lodash.
 * @param {Array<Object>} users - Array de objetos de usuario.
 * @returns {Array<Object>} Array de objetos ordenado y filtrado.
 */
function prepareData(users) {
    // 1. Filtrar usuarios activos
    const activeUsers = _.filter(users, { status: 'active' });
    
    // 2. Ordenar por nombre
    const sortedUsers = _.sortBy(activeUsers, 'name');
    
    // 3. Devolver los primeros 5
    return _.take(sortedUsers, 5);
}


/**
 * Función central de la aplicación: saluda a un nombre dado.
 * @param {string} name - El nombre a saludar.
 * @returns {string} El mensaje de saludo.
 */
function greet(name) {
    // 💡 CLAVE: Lee la variable de entorno 'APP_COLOR' inyectada en el Dockerfile.
    const appColor = process.env.APP_COLOR || "Mundo"; 

    if (!name) {
        return `Hola! Soy ${appColor}`; // Mensaje modificado
    }
    return `Hola, ${name}! Bienvenido a CI/CD. (Desde ${appColor})`; // Mensaje modificado
}

// Exporta las funciones para poder ser probadas
module.exports = { greet, calculateHeavyMetric, prepareData };


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