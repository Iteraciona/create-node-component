#!/bin/bash

# --- Paleta de Colores ---
BOLD="\033[1m"
BLUE="\033[34m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# --- Datos de la Herramienta ---
VERSION="v1.0.0"
AUTHOR="eric@iteraciona.com"
URL="www.iteraciona.com"
ORG="Iteraciona © 2026"
LICENSE="MIT"

# --- Funciones de Utilidad ---

# Función para calcular el path relativo del require/import
calcular_path_relativo() {
    local desde="$1"
    local hasta="$2"
    
    desde=$(echo "$desde" | sed 's|^\./||')
    hasta=$(echo "$hasta" | sed 's|^\./||')

    local niveles=$(echo "$desde" | tr -cd '/' | wc -c)
    local prefijo=""
    for ((i=0; i<niveles; i++)); do
        prefijo="../$prefijo"
    done
    
    [ -z "$prefijo" ] && prefijo="./"
    echo "${prefijo}${hasta}" | sed 's|//|/|g' | sed 's|^\./\./|./|'
}

# Función para menús interactivos con flechas
seleccionar_opcion() {
    local titulo="$1"
    shift
    local opciones=("$@")
    local seleccionada=0
    local num_opciones=${#opciones[@]}
    local tecla

    tput civis
    trap "tput cnorm; exit" INT TERM

    while true; do
        clear
        echo -e "${BOLD}${BLUE}==============================================${RESET}"
        echo -e "${BOLD}           GENERADOR DE COMPONENTES           ${RESET}"
        echo -e "                 ${VERSION}                      "
        echo -e "          ${ORG} (${LICENSE})             "
        echo -e "              ${URL}              "
        echo -e "${BOLD}${BLUE}==============================================${RESET}"
        echo -e "${CYAN}${titulo}${RESET}"
        echo -e "${YELLOW}Usa las flechas (↑ ↓) o el número y pulsa Enter${RESET}"
        echo -e "${RED}(Presiona Ctrl+C para salir)${RESET}"
        echo ""

        for i in "${!opciones[@]}"; do
            if [ $i -eq $seleccionada ]; then
                printf "  ${GREEN}${BOLD}▶ %d. %s${RESET}\n" $((i+1)) "${opciones[$i]}"
            else
                printf "     %d. %s\n" $((i+1)) "${opciones[$i]}"
            fi
        done

        IFS= read -rsn1 tecla
        if [[ $tecla == $'\x1b' ]]; then
            read -rsn2 tecla
            if [[ $tecla == "[A" ]]; then [ $seleccionada -gt 0 ] && ((seleccionada--)); fi
            if [[ $tecla == "[B" ]]; then [ $seleccionada -lt $(( num_opciones - 1 )) ] && ((seleccionada++)); fi
        elif [[ $tecla =~ [1-9] ]] && [ $tecla -le $num_opciones ]; then
            seleccionada=$((tecla-1)); tput cnorm; return $seleccionada
        elif [[ $tecla == "" ]]; then
            tput cnorm; return $seleccionada
        fi
    done
}

# --- Detección Automática de Estructura ---
detectar_entorno() {
    HAS_SRC=false
    [ -d "src" ] && HAS_SRC=true

    if [ "$HAS_SRC" = true ]; then
        if [ -d "src/modules" ]; then DEFAULT_TARGET="src/modules"
        elif [ -d "src/components" ]; then DEFAULT_TARGET="src/components"
        else DEFAULT_TARGET="src/modules"; fi
    else
        if [ -d "modules" ]; then DEFAULT_TARGET="modules"
        elif [ -d "components" ]; then DEFAULT_TARGET="components"
        else DEFAULT_TARGET="modules"; fi
    fi

    POSIBLES_RUTAS=()
    CANDIDATOS=(
        "src/routes/v1/index.js" "src/routes/v1/routes.js" "src/routes/index.js" "src/routes.js" "src/app.js"
        "routes/v1/index.js" "routes/v1/routes.js" "routes/index.js" "routes.js" "app.js" "index.js"
    )
    
    for c in "${CANDIDATOS[@]}"; do
        if [ -f "$c" ]; then
            POSIBLES_RUTAS+=("$c")
        fi
    done
    
    POSIBLES_RUTAS+=("Introducir ruta manualmente" "No registrar")
}

# --- Inicio del Script ---

detectar_entorno

clear
echo -e "${BOLD}${BLUE}==============================================${RESET}"
echo -e "${BOLD}           GENERADOR DE COMPONENTES           ${RESET}"
echo -e "                 ${VERSION}                      "
echo -e "          ${ORG} (${LICENSE})             "
echo -e "              ${URL}              "
echo -e "${BOLD}${BLUE}==============================================${RESET}"
echo -e "${YELLOW}Nota: Estructura detectada. Rutas relativas a la raíz.${RESET}"
echo -e "${RED}(Presiona Ctrl+C para salir)${RESET}\n"

# 1. Analizar argumentos iniciales
INPUT_PATH=$1
if [ -n "$INPUT_PATH" ]; then
    if [[ "$INPUT_PATH" == */* ]]; then
        TARGET_DIR=$(dirname "$INPUT_PATH")
        COMPONENT_NAME=$(basename "$INPUT_PATH")
    else
        COMPONENT_NAME="$INPUT_PATH"
        TARGET_DIR=$2
    fi
fi

if [ -z "$COMPONENT_NAME" ]; then
    printf "${CYAN}➤ Nombre del componente (ej. Project):${RESET} "
    read COMPONENT_NAME
fi

if [ -z "$TARGET_DIR" ]; then
    printf "${CYAN}➤ Directorio de destino [${DEFAULT_TARGET}]:${RESET} "
    read TARGET_DIR
    TARGET_DIR=${TARGET_DIR:-$DEFAULT_TARGET}
fi

COMPONENT_PATH=$(echo "$TARGET_DIR/$COMPONENT_NAME" | sed 's|^\./||' | sed 's|//|/|g')

if [ -d "$COMPONENT_PATH" ]; then
    echo -e "\n${RED}${BOLD}Error: El componente '$COMPONENT_NAME' ya existe en $COMPONENT_PATH.${RESET}"
    exit 1
fi

# 2. Menús de Configuración
opciones_modulo=("ESM (import/export) [Default]" "CommonJS (require/module.exports)")
seleccionar_opcion "Selecciona el sistema de módulos:" "${opciones_modulo[@]}"
SISTEMA_MODULO=$?

opciones_gen=("Archivos vacíos" "Ruta básica + list()" "CRUD completo (Mongoose + Validators)")
seleccionar_opcion "Selecciona el tipo de generación:" "${opciones_gen[@]}"
TIPO_GEN=$?

seleccionar_opcion "Selecciona dónde registrar las rutas:" "${POSIBLES_RUTAS[@]}"
REG_RUTA_OPC=$?

# 3. Validación de archivo de rutas
ARCHIVO_RUTAS=""
OPCION_ELEGIDA="${POSIBLES_RUTAS[$REG_RUTA_OPC]}"

if [ "$OPCION_ELEGIDA" = "Introducir ruta manualmente" ]; then
    printf "\n${CYAN}➤ Introduce la ruta del archivo (ej. src/app.js):${RESET} "
    read ARCHIVO_RUTAS
elif [ "$OPCION_ELEGIDA" != "No registrar" ]; then
    ARCHIVO_RUTAS="$OPCION_ELEGIDA"
fi

# Preguntar si se desea crear el archivo si no existe
if [ -n "$ARCHIVO_RUTAS" ] && [ ! -f "$ARCHIVO_RUTAS" ]; then
    printf "\n${YELLOW}El archivo no existe: %s${RESET}\n" "$ARCHIVO_RUTAS"
    printf "${CYAN}¿Deseas crearlo ahora? [Y/n]:${RESET} "
    read CREATE_FILE_ANS
    CREATE_FILE_ANS=${CREATE_FILE_ANS:-"Y"}
    if [[ "$CREATE_FILE_ANS" =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$ARCHIVO_RUTAS")"
        if [ $SISTEMA_MODULO -eq 0 ]; then
            cat <<EOF > "$ARCHIVO_RUTAS"
import express from 'express';
const router = express.Router();

export default router;
EOF
        else
            cat <<EOF > "$ARCHIVO_RUTAS"
const express = require('express');
const router = express.Router();

module.exports = router;
EOF
        fi
        echo -e "${GREEN}✔ Archivo $ARCHIVO_RUTAS creado con éxito.${RESET}"
    else
        echo -e "${YELLOW}Aviso: No se registrará la ruta automáticamente.${RESET}"
        ARCHIVO_RUTAS=""
        sleep 1
    fi
fi

# --- Ejecución de carpetas del módulo ---
echo -e "\n${BLUE}${BOLD}Generando archivos del componente...${RESET}"

mkdir -p "$COMPONENT_PATH/controllers" "$COMPONENT_PATH/models" "$COMPONENT_PATH/routes" "$COMPONENT_PATH/services" "$COMPONENT_PATH/validators"

case $TIPO_GEN in
    0) # Vacíos
        touch "$COMPONENT_PATH/controllers/${COMPONENT_NAME}Controller.js"
        touch "$COMPONENT_PATH/models/${COMPONENT_NAME}Model.js"
        touch "$COMPONENT_PATH/routes/${COMPONENT_NAME}Routes.js"
        touch "$COMPONENT_PATH/services/${COMPONENT_NAME}Service.js"
        touch "$COMPONENT_PATH/validators/${COMPONENT_NAME}Validator.js"
        ;;
    1) # Básica
        if [ $SISTEMA_MODULO -eq 0 ]; then
            cat <<EOF > "$COMPONENT_PATH/controllers/${COMPONENT_NAME}Controller.js"
export const list = async (req, res) => {
  try {
    res.status(200).json({ message: 'Lista de ${COMPONENT_NAME}' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
EOF
            cat <<EOF > "$COMPONENT_PATH/routes/${COMPONENT_NAME}Routes.js"
import express from 'express';
import * as ${COMPONENT_NAME}Controller from '../controllers/${COMPONENT_NAME}Controller.js';

const router = express.Router();

router.get('/', ${COMPONENT_NAME}Controller.list);

export default router;
EOF
        else
            cat <<EOF > "$COMPONENT_PATH/controllers/${COMPONENT_NAME}Controller.js"
const list = async (req, res) => {
  try {
    res.status(200).json({ message: 'Lista de ${COMPONENT_NAME}' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
module.exports = { list };
EOF
            cat <<EOF > "$COMPONENT_PATH/routes/${COMPONENT_NAME}Routes.js"
const express = require('express');
const router = express.Router();
const ${COMPONENT_NAME}Controller = require('../controllers/${COMPONENT_NAME}Controller');

router.get('/', ${COMPONENT_NAME}Controller.list);

module.exports = router;
EOF
        fi
        touch "$COMPONENT_PATH/models/${COMPONENT_NAME}Model.js"
        touch "$COMPONENT_PATH/services/${COMPONENT_NAME}Service.js"
        touch "$COMPONENT_PATH/validators/${COMPONENT_NAME}Validator.js"
        ;;
    2) # CRUD
        if [ $SISTEMA_MODULO -eq 0 ]; then
            # ESM CRUD
            cat <<EOF > "$COMPONENT_PATH/controllers/${COMPONENT_NAME}Controller.js"
import * as ${COMPONENT_NAME}Service from '../services/${COMPONENT_NAME}Service.js';

export const getAll = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.findAll();
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const getById = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.findById(req.params.id);
    if (!data) return res.status(404).json({ message: 'Not found' });
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const create = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.create(req.body);
    res.status(201).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const update = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.update(req.params.id, req.body);
    if (!data) return res.status(404).json({ message: 'Not found' });
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const remove = async (req, res) => {
  try {
    const success = await ${COMPONENT_NAME}Service.remove(req.params.id);
    if (!success) return res.status(404).json({ message: 'Not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
EOF
            cat <<EOF > "$COMPONENT_PATH/models/${COMPONENT_NAME}Model.js"
import mongoose from 'mongoose';

const ${COMPONENT_NAME}Schema = new mongoose.Schema({
  name: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
}, { versionKey: false });

export default mongoose.model('${COMPONENT_NAME}', ${COMPONENT_NAME}Schema);
EOF
            cat <<EOF > "$COMPONENT_PATH/validators/${COMPONENT_NAME}Validator.js"
import { body, validationResult } from 'express-validator';

export const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
};

export const validateCreate = [
  body('name').notEmpty().withMessage('Name is required'),
  handleValidationErrors
];

export const validateUpdate = [
  body('name').optional().notEmpty().withMessage('Name cannot be empty'),
  handleValidationErrors
];
EOF
            cat <<EOF > "$COMPONENT_PATH/routes/${COMPONENT_NAME}Routes.js"
import express from 'express';
import * as ${COMPONENT_NAME}Controller from '../controllers/${COMPONENT_NAME}Controller.js';
import * as ${COMPONENT_NAME}Validator from '../validators/${COMPONENT_NAME}Validator.js';

const router = express.Router();

router.get('/', ${COMPONENT_NAME}Controller.getAll);
router.get('/:id', ${COMPONENT_NAME}Controller.getById);
router.post('/', ${COMPONENT_NAME}Validator.validateCreate, ${COMPONENT_NAME}Controller.create);
router.put('/:id', ${COMPONENT_NAME}Validator.validateUpdate, ${COMPONENT_NAME}Controller.update);
router.delete('/:id', ${COMPONENT_NAME}Controller.remove);

export default router;
EOF
            cat <<EOF > "$COMPONENT_PATH/services/${COMPONENT_NAME}Service.js"
import ${COMPONENT_NAME} from '../models/${COMPONENT_NAME}Model.js';

export const findAll = () => ${COMPONENT_NAME}.find();
export const findById = (id) => ${COMPONENT_NAME}.findById(id);
export const create = (data) => new ${COMPONENT_NAME}(data).save();
export const update = (id, data) => ${COMPONENT_NAME}.findByIdAndUpdate(id, data, { new: true });
export const remove = (id) => ${COMPONENT_NAME}.findByIdAndDelete(id);
EOF
        else
            cat <<EOF > "$COMPONENT_PATH/controllers/${COMPONENT_NAME}Controller.js"
const ${COMPONENT_NAME}Service = require('../services/${COMPONENT_NAME}Service');

const getAll = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.findAll();
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const getById = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.findById(req.params.id);
    if (!data) return res.status(404).json({ message: 'Not found' });
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const create = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.create(req.body);
    res.status(201).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const update = async (req, res) => {
  try {
    const data = await ${COMPONENT_NAME}Service.update(req.params.id, req.body);
    if (!data) return res.status(404).json({ message: 'Not found' });
    res.status(200).json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const success = await ${COMPONENT_NAME}Service.remove(req.params.id);
    if (!success) return res.status(404).json({ message: 'Not found' });
    res.status(204).send();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getAll, getById, create, update, remove };
EOF
            cat <<EOF > "$COMPONENT_PATH/models/${COMPONENT_NAME}Model.js"
const mongoose = require('mongoose');

const ${COMPONENT_NAME}Schema = new mongoose.Schema({
  name: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
}, { versionKey: false });

module.exports = mongoose.model('${COMPONENT_NAME}', ${COMPONENT_NAME}Schema);
EOF
            cat <<EOF > "$COMPONENT_PATH/validators/${COMPONENT_NAME}Validator.js"
const { body, validationResult } = require('express-validator');

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  next();
};

const validateCreate = [
  body('name').notEmpty().withMessage('Name is required'),
  handleValidationErrors
];

const validateUpdate = [
  body('name').optional().notEmpty().withMessage('Name cannot be empty'),
  handleValidationErrors
];

module.exports = { validateCreate, validateUpdate };
EOF
            cat <<EOF > "$COMPONENT_PATH/routes/${COMPONENT_NAME}Routes.js"
const express = require('express');
const router = express.Router();
const ${COMPONENT_NAME}Controller = require('../controllers/${COMPONENT_NAME}Controller');
const ${COMPONENT_NAME}Validator = require('../validators/${COMPONENT_NAME}Validator');

router.get('/', ${COMPONENT_NAME}Controller.getAll);
router.get('/:id', ${COMPONENT_NAME}Controller.getById);
router.post('/', ${COMPONENT_NAME}Validator.validateCreate, ${COMPONENT_NAME}Controller.create);
router.put('/:id', ${COMPONENT_NAME}Validator.validateUpdate, ${COMPONENT_NAME}Controller.update);
router.delete('/:id', ${COMPONENT_NAME}Controller.remove);

module.exports = router;
EOF
            cat <<EOF > "$COMPONENT_PATH/services/${COMPONENT_NAME}Service.js"
const ${COMPONENT_NAME} = require('../models/${COMPONENT_NAME}Model');

const findAll = () => ${COMPONENT_NAME}.find();
const findById = (id) => ${COMPONENT_NAME}.findById(id);
const create = (data) => new ${COMPONENT_NAME}(data).save();
const update = (id, data) => ${COMPONENT_NAME}.findByIdAndUpdate(id, data, { new: true });
const remove = (id) => ${COMPONENT_NAME}.findByIdAndDelete(id);

module.exports = { findAll, findById, create, update, remove };
EOF
        fi
        ;;
esac

# 4. Inyección en el archivo de rutas (ya validado o creado)
if [ -n "$ARCHIVO_RUTAS" ]; then
    NOMBRE_VAR_LOWER=$(echo "$COMPONENT_NAME" | tr '[:upper:]' '[:lower:]')
    PATH_RELATIVO=$(calcular_path_relativo "$ARCHIVO_RUTAS" "$COMPONENT_PATH")
    
    printf "\n// Rutas para %s\n" "$COMPONENT_NAME" >> "$ARCHIVO_RUTAS"
    if [ $SISTEMA_MODULO -eq 0 ]; then
        printf "import %sRoutes from '%s/routes/%sRoutes.js';\n" "$NOMBRE_VAR_LOWER" "$PATH_RELATIVO" "$COMPONENT_NAME" >> "$ARCHIVO_RUTAS"
    else
        printf "const %sRoutes = require('%s/routes/%sRoutes');\n" "$NOMBRE_VAR_LOWER" "$PATH_RELATIVO" "$COMPONENT_NAME" >> "$ARCHIVO_RUTAS"
    fi
    printf "router.use('/%s', %sRoutes);\n" "$NOMBRE_VAR_LOWER" "$NOMBRE_VAR_LOWER" >> "$ARCHIVO_RUTAS"
    printf "\n${GREEN}✔ Registrado correctamente en %s${RESET}\n" "$ARCHIVO_RUTAS"
fi

printf "\n${GREEN}${BOLD}✔ ¡Listo! Componente '%s' creado con éxito.${RESET}\n" "$COMPONENT_NAME"
printf "${BLUE}Carpeta:${RESET} %s\n" "$COMPONENT_PATH"
printf "${BLUE}Sistema:${RESET} %s\n" "${opciones_modulo[$SISTEMA_MODULO]}"
