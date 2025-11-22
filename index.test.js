// index.test.js

const { greet } = require('./index');

describe('Función de Saludo (greet)', () => {
    
    // Prueba 1: Verifica el saludo con un nombre
    test('Debe saludar correctamente a un nombre dado', () => {
        const name = 'Desarrollador';
        const expected = 'Hola, Desarrollador! Bienvenido a CI/CD.';
        expect(greet(name)).toBe(expected);
    });

    // Prueba 2: Verifica el saludo por defecto (sin nombre)
    test('Debe devolver el saludo por defecto si no se proporciona un nombre', () => {
        const expected = 'Hola, mundo!';
        expect(greet()).toBe(expected);
    });
    
    // Puedes añadir más pruebas, como validar que el parámetro sea una cadena, etc.
    test('Debe manejar un nombre vacío', () => {
        const name = '';
        const expected = 'Hola, mundo!';
        expect(greet(name)).toBe(expected);
    });

});