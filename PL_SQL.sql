-- TOTAL PUNTOS: 9
-- Borra y crea de nuevo el esquema de usuario EmpleDepart.
-- Crea una tabla AVISOS con los campos ejercicio (texto), mensaje (texto) y
-- fecha, donde se almacenarán los avisos generados por los distintos ejercicios.
-- 1. (0,5 ptos) Crea un bloque PL/SQL anónimo que al insertar un nuevo registro
-- de un empleado en la tabla EMPLE, le ponga como código de empleado
-- (emple_no) el último código de empleado existente más 10.
-- Ten en cuenta que la tabla podría estar vacía.
-- (0,25 ptos) Pide por consola al usuario el resto de datos del nuevo
-- empleado (los obligatorios), dejando en NULOS los campos no obligatorios.
-- (0,25 ptos) Inserta en tabla AVISOS el mensaje de la acción realizada

create table avisos(
    mensaje varchar2(400)
);

SET SERVEROUTPUT ON;

DECLARE
  n_emp SMALLINT;
  apellido VARCHAR2(10);
  oficio VARCHAR2(10);
  dir SMALLINT := NULL;
  fecha_alt DATE;
  salario NUMBER(6,2);
  comision NUMBER(6,2) := NULL;
  n_depart SMALLINT;
BEGIN
  n_emp := &nuevo_empleado;
  apellido := '&apellido';
  oficio := '&oficio';
  fecha_alt := TO_DATE('&fecha_alt', 'DD/MM/YYYY');
  salario := &salario;
  n_depart := &n_departamento;
  
  INSERT INTO emple VALUES (n_emp, apellido, oficio, dir, fecha_alt, salario, comision, n_depart);
  
  DBMS_OUTPUT.PUT_LINE('Nuevo empleado insertado correctamente');
END;
/

-- 2. (1,5 ptos) La nueva directiva de la empresa quiere que no exista una gran
-- diferencia de salarios entre los que ganan más y los que ganan menos, han
-- fijado la máxima diferencia en 3 veces el salario mínimo de la empresa,
-- realiza un procedimiento que permita detectar si se da o no esta condición
-- con los empleados que hay actualmente. Guarda en AVISOS la información
-- de si hay o no esa desigualdad. No es necesario mirar los empleados
-- individualmente.



CREATE OR REPLACE PROCEDURE DETECTAR_SALARIO AS
    v_salario_minimo emple.salario%TYPE;
    v_salario_maximo emple.salario%TYPE;
    v_diferencia_salarial NUMBER(8,2);
BEGIN
    -- Obtener salario mínimo, salario máximo y diferencia salarial
    SELECT MIN(salario), MAX(salario), (MAX(salario) - MIN(salario)) INTO v_salario_minimo, v_salario_maximo, v_diferencia_salarial
    FROM emple;
    
    -- Comparar diferencia salarial con 3 veces el salario mínimo
    IF v_diferencia_salarial <= (3 * v_salario_minimo) THEN
        INSERT INTO avisos (mensaje) VALUES ('El salario es igual');
    ELSE
        INSERT INTO avisos (mensaje) VALUES ('No es igual el salario');
    END IF;
END;
/

-- 3. (1,5 ptos) Queremos saber cuáles son l@s emplead@s que cobran menos
-- del triple que el salario más alto de la empresa. Almacena en AVISOS los
-- mensajes de quienes son y sus salarios, indicando los que cobran menos
-- de la tercera parte del máximo

DECLARE
    v_salario_maximo NUMBER;
BEGIN
    -- Obtener el salario máximo de la empresa
    SELECT MAX(salario) INTO v_salario_maximo FROM emple;

    -- Buscar a los empleados que ganan menos del triple del salario máximo
    FOR emp IN (SELECT * FROM emple WHERE salario < v_salario_maximo*3)
    LOOP
        -- Almacenar el mensaje en la tabla AVISOS
        IF emp.salario < v_salario_maximo/3 THEN
            INSERT INTO avisos (mensaje) VALUES ('El empleado ' || emp.nombre || ' gana ' || emp.salario || ', que es menos de la tercera parte del salario máximo.');
        ELSE
            INSERT INTO avisos (mensaje) VALUES ('El empleado ' || emp.nombre || ' gana ' || emp.salario || '.');
        END IF;
    END LOOP;
END;

-- 4. La directiva decide realizar ese análisis de diferencias de salarios, pero a
-- nivel de departamento, es decir, no debe haber una diferencia superior al
-- triple entre quien tiene un salario mínimo y máximo dentro del mismo
-- departamento.
-- (1 pto) Realiza una función a la que se le pase un número de empleado y
-- devuelva un valor booleano (true o false) si el salario de es@ emplead@
-- incumple la nueva norma de la empresa (por arriba o por abajo).
-- (1 pto) Realiza un procedimiento que mire todos los empleados de la
-- empresa y que utilice la anterior función para saber si cada emplead@ tiene
-- o no un salario superior al triple del mínimo o menos de la tercera parte del
-- máximo de su departamento. En el caso de que sea así, debe almacenar un
-- mensaje indicándolo en AVISOS.



-- Función para determinar si el salario de un empleado incumple la nueva norma de la empresa para su departamento
CREATE OR REPLACE FUNCTION salario_incumple_norma(p_emp_no IN NUMBER) RETURN BOOLEAN AS
  v_salario_emp NUMBER;
  v_salario_min_dept NUMBER;
  v_salario_max_dept NUMBER;
BEGIN
  -- Obtener el salario del empleado
  SELECT salary INTO v_salario_emp FROM emple WHERE emp_no = p_emp_no;

  -- Obtener los salarios mínimo y máximo del departamento del empleado
  SELECT MIN(salary), MAX(salary) INTO v_salario_min_dept, v_salario_max_dept FROM emple WHERE dept_no = (SELECT dept_no FROM emple WHERE emp_no = p_emp_no);

  -- Determinar si el salario del empleado incumple la nueva norma de la empresa para su departamento
  IF v_salario_emp < v_salario_min_dept/3 OR v_salario_emp > v_salario_max_dept*3 THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
/

-- Procedimiento para verificar todos los empleados y guardar los mensajes correspondientes en la tabla AVISOS
CREATE OR REPLACE PROCEDURE verificar_salarios_norma IS
BEGIN
  -- Iterar sobre todos los empleados
  FOR emp IN (SELECT * FROM emple)
  LOOP
    -- Verificar si el salario del empleado incumple la nueva norma de la empresa para su departamento
    IF salario_incumple_norma(emp.emp_no) THEN
      -- Almacenar el mensaje en la tabla AVISOS
      INSERT INTO avisos (mensaje) VALUES ('El empleado ' || emp.nombre || ' con número de empleado ' || emp.emp_no || ' incumple la nueva norma de la empresa para su departamento.');
    END IF;
  END LOOP;
END;
/
-- 5. (3 ptos) Realiza un trigger compuesto para controlar que esa diferencia a
-- nivel de departamento no se cumpla en futuros cambios o inserciones en la
-- base de datos. Si se incumple esta condición, se guarda esta circunstancia
-- en AVISOS y se impide dicha operación.
-- Tienes que tener en cuenta que se pueden dar dos circunstancias distintas:
-- • Que el nuevo emplead@ (o cambio en salario de empleados
-- actuales) esté por debajo de este rango de diferencia.
-- • Que el nuevo emplead@ (o cambio en salario de empleados
-- actuales) esté por encima de este rango de diferencia.



CREATE OR REPLACE TRIGGER tr_control_salarios
BEFORE INSERT OR UPDATE ON emple
FOR EACH ROW
DECLARE
    v_min_salary emple.salario%TYPE;
    v_max_salary emple.salario%TYPE;
    v_salario_triple emple.salario%TYPE;
    v_deptno emple.deptno%TYPE;
BEGIN
    -- Obtener el salario mínimo, salario máximo y departamento del empleado actual o nuevo
    SELECT MIN(salario), MAX(salario), deptno INTO v_min_salary, v_max_salary, v_deptno
    FROM emple
    WHERE deptno = :NEW.deptno
    GROUP BY deptno;

    -- Obtener el valor del salario máximo multiplicado por tres
    v_salario_triple := v_max_salary * 3;

    -- Verificar que el nuevo salario no exceda el triple del salario mínimo ni sea inferior a la tercera parte del salario máximo
    IF :NEW.salario > v_salario_triple OR :NEW.salario < v_max_salary/3 THEN
        -- Almacenar el mensaje en la tabla AVISOS
        INSERT INTO avisos (mensaje) VALUES ('El empleado ' || :NEW.nombre || ' con identificador ' || :NEW.id || ' del departamento ' || v_deptno || ' no cumple con la norma de salarios.');

        -- Impedir la operación
        RAISE_APPLICATION_ERROR(-20000, 'El salario del empleado ' || :NEW.nombre || ' no cumple con la norma de salarios del departamento ' || v_deptno || '.');
    END IF;
END;
/
