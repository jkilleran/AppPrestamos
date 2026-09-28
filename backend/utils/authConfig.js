require('dotenv').config();

function requireEnvironmentVariable(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(
      `[CONFIG] ${name} es obligatorio. Definelo en backend/.env antes de iniciar la API.`
    );
  }
  return value;
}

const JWT_SECRET = requireEnvironmentVariable('JWT_SECRET');

module.exports = { JWT_SECRET };
