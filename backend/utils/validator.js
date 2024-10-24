import validator from "validator";
export const isEmail = (entity) => {
    return validator.isEmail(entity);
};

export const isNumber = (entity) => {
    return validator.isNumeric(entity);
};