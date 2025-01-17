USE [SGVENTAS_PRD]
GO
/****** Object:  StoredProcedure [dbo].[sp_Reporte_Seguimiento_x_fechas]    Script Date: 5/07/2024 17:33:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROC [dbo].[sp_Reporte_Seguimiento_x_fechas]
    @desde VARCHAR(10) = '',
    @hasta VARCHAR(10) = '',
    @id_campania INT = 0,
    @accion VARCHAR(200) = '',
    @respuesta VARCHAR(200) = '',
    @agrupador INT = 0,
    @area VARCHAR(200) = '',
    @programa VARCHAR(200) = '',
    @id_usuario INT = 0,
    @desde_registro VARCHAR(10) = '',
    @hasta_registro VARCHAR(10) = '',
    @id_unidad_negocio INT = 0,
    @id_evento INT = 0,
    @id_proyecto INT = 0,
    @sexo CHAR(1) = '',
    @AnioDesde INT = 0,
    @AnioHasta INT = 0,
    @UltimaActividad INT = 0,
    @Oportunidad VARCHAR(200) = ''
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_agrupador INT = @agrupador,
            @nwhere NVARCHAR(MAX) = '',
            @nsqlfinal NVARCHAR(MAX) = '',
            @uso INT = 0,
            @IdUnidadNegocio INT = (SELECT id_unidad_negocio FROM Agrupador WHERE id_agrupador = @agrupador),
            @desdeOK SMALLDATETIME = (SELECT fecha_inicio FROM Campania WHERE id_campania = @id_campania);

    DECLARE @TablaOportunidad TABLE (Oportunidad VARCHAR(MAX));
    INSERT INTO @TablaOportunidad (Oportunidad)
    SELECT * FROM dbo.FNC_SEG_SplitCadena(@Oportunidad, ',');

    DECLARE @Condiciones TABLE (Condicion NVARCHAR(MAX));
    
    IF @desde <> '' AND @hasta <> ''
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.fecha BETWEEN ''' + @desde + ' 00:00:00'' AND ''' + @hasta + ' 23:59:59''');

    IF @desde_registro <> '' AND @hasta_registro <> ''
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.fecha_registro BETWEEN ''' + @desde_registro + ' 00:00:00'' AND ''' + @hasta_registro + ' 23:59:59''');

    IF @id_campania > 0
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.id_campania = ' + LTRIM(RTRIM(STR(@id_campania))));

    IF @agrupador > 0
        INSERT INTO @Condiciones (Condicion) VALUES ('Area.id_agrupador = ' + LTRIM(RTRIM(STR(@agrupador))));

    IF @accion <> ''
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.id_tipo_atencion IN (' + @accion + ')');

    IF @respuesta <> ''
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.id_respuesta_1n IN (' + @respuesta + ')');

    IF @area <> ''
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.id_area IN (' + @area + ')');

    IF @programa <> ''
        INSERT INTO @Condiciones (Condicion) VALUES ('Actividad.id_programa IN (' + @programa + ')');

    IF @AnioDesde > 0 AND @AnioHasta > 0
        INSERT INTO @Condiciones (Condicion) VALUES ('ISNULL((SELECT TOP 1 anio_fin FROM ClienteEstudioColegio WHERE id_unidad_negocio = ' + STR(@IdUnidadNegocio) + ' AND ClienteEstudioColegio.id_Cliente = Actividad.id_cliente ORDER BY anio_fin DESC), 0) BETWEEN ' + STR(@AnioDesde) + ' AND ' + STR(@AnioHasta) + '');

    -- Concatenar todas las condiciones
    SELECT @nwhere = STRING_AGG(Condicion, ' AND ') FROM @Condiciones;

    PRINT @nwhere;

    SET DATEFORMAT DMY;
    DECLARE @sql NVARCHAR(MAX);
    CREATE TABLE #datos (id_actividad INT, tipo_tabla INT);

    IF @UltimaActividad = 0
    BEGIN
        SET @sql = N'
            INSERT INTO #datos
            SELECT id_actividad, tipo_tabla FROM Actividad WITH (NOLOCK)
            INNER JOIN Area ON Area.id_area = Actividad.id_area
            WHERE ' + @nwhere + '
            UNION
            SELECT id_actividad_historica, tipo_tabla FROM ActividadHistoricaSisproven Actividad WITH (NOLOCK)
            INNER JOIN Area ON Area.id_area = Actividad.id_area
            WHERE ' + @nwhere;
    END
    ELSE
    BEGIN
        SET @sql = N'
            INSERT INTO #datos
            SELECT id_actividad, tipo_tabla FROM Actividad_Ultima Actividad WITH (NOLOCK)
            INNER JOIN Area ON Area.id_area = Actividad.id_area
            WHERE ' + @nwhere + '
            UNION
            SELECT id_actividad_historica, tipo_tabla FROM ActividadHistoricaSisproven Actividad WITH (NOLOCK)
            INNER JOIN Area ON Area.id_area = Actividad.id_area
            WHERE ' + @nwhere;
    END

    EXEC sp_executesql @sql;
  
 IF @UltimaActividad = 0  
  
  BEGIN  
   IF @accion IN ( '8', '6', '7', '11', '2', '3', '12', '15', '9', '4', '5',  
       '55', '10' )  
    BEGIN  
     SELECT  Cliente.id_cliente,  LTRIM(RTRIM(Cliente.apellido_paterno)) + ' ' + LTRIM(RTRIM(Cliente.apellido_materno)) apellidos , LTRIM(RTRIM(Cliente.nombres)) nombres,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion, Distrito.nombre distrito,  
       ISNULL(( SELECT TOP ( 1 ) ISNULL(p.nombre, '')  
                FROM Provincia p  
                WHERE p.id_provincia = Distrito.id_provincia), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 ) ISNULL(d.nombre, '')  
                FROM Provincia p  
                INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
                WHERE p.id_provincia = Distrito.id_provincia), '') 'Departamento' ,  
       Cliente.telefono,  
       ISNULL(Cliente.celular, '') celular,  
       ISNULL(Cliente.celular2, '') celular2,  
       ISNULL(Cliente.email1, '') email1,  
       ISNULL(Cliente.email2, '') email2,  
       TipoAtencion.tipo_atencion accion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta respuesta_2_nivel ,  
       (SELECT STUFF(( SELECT  ', ' + mi.medio_informa  
        FROM ActividadMedioInformaDetalle am  
        INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
        WHERE id_actividad = Actividad.id_actividad AND id_cliente = Actividad.id_cliente  
        FOR XML PATH('')), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion,  
       CAST(CONVERT(NVARCHAR, Actividad.fecha, 103) + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) fecha_accion,  
       CAST(CONVERT(NVARCHAR, Actividad.fecha_registro, 103) + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) fecha_registro,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1 C.colegio  
         FROM ClienteEstudioColegio CE, Colegio C  
         WHERE CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) colegio ,  
       ( SELECT TOP 1 D.nombre  
         FROM ClienteEstudioColegio CE, Colegio C, Distrito D  
         WHERE CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND C.id_distrito = D.id_distrito  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
        ORDER BY  CE.id_cli_est_colegio DESC  
       ) distrito_colegio ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) grado ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) anio_fin ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) periodo ,  
       Usuario.nombres + ' ' + Usuario.apellidos vendedor ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) edad ,  
       Profesion.profesion, EstadoCivil.estado_civil est_civil, Nacionalidad.nacionalidad, Campania.nombre campania, UnidadNegocio.unidad_negocio,  
       CASE 
        WHEN (SELECT efectiva  
              FROM Efectivas_NoEfectivas  
              WHERE Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
              AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n) = 1 THEN 'EFECTIVA'  
        ELSE 'NO EFECTIVA'  
       END efec_NoEfect ,  
       Actividad.id_actividad ,  
       CASE WHEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '') = ''  
         THEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Usuario.IdSede  
            ), '')  
         ELSE ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '')  
       END Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) 'Condición' ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor'  
         
       -- , dbo.fn_Asesor_Contacto(Cliente.id_cliente, @agrupador) 'Asesor Contacto'  
       ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
             THEN CASE WHEN ISNULL(Actividad.id_usuario_venta,  
                 0) <> 0  
              THEN ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   WHERE  
                   UR.id_usuario = Actividad.id_usuario_venta  
                 ), '')  
              ELSE ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                 ), '')  
            END  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
       END 'Asesor Contacto' ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM      ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ( SELECT    T.tipo_atencion  
         FROM      Actividad_Ultima A  
          INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Útl. Acción' ,  
       ( SELECT    R.respuesta  
         FROM      Actividad_Ultima A  
          INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Últ. Respuesta' ,  
       ( SELECT TOP 1  
          R.respuesta  
         FROM      Actividad_Ultima A  
          LEFT JOIN Respuesta_2_N R ON A.id_respuesta_2n = R.id_respuesta_2_N  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Respuesta 2do Nivel' ,  
       ( SELECT TOP 1  
          A.descripcion  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Observación' ,  
       ( SELECT TOP 1  
          CAST(CONVERT(NVARCHAR, A.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), A.fecha, 108) AS SMALLDATETIME) fecha  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Fecha Útl. Acción' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE ( SELECT TOP 1  
            U.apellidos + ' ' + U.nombres asesor  
          FROM    Actividad_Ultima A  
            INNER JOIN Usuario U ON A.id_usuario = U.id_usuario  
            INNER JOIN Area B ON A.id_area = B.id_area  
          WHERE   A.id_cliente = Cliente.id_cliente  
            AND B.id_agrupador = @agrupador  
           )  
       END AS 'Últ. Asesor' ,  
       ( SELECT TOP 1  
          G.grado_interes  
         FROM      Actividad_Ultima A  
          INNER JOIN GradoInteres G ON A.id_grado = G.id_grado  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Grado Interés' ,  
       ( SELECT TOP 1  
          B.area  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Área' ,  
       ( SELECT TOP 1  
          C.programa  
         FROM      Actividad_Ultima A  
          INNER JOIN Programa C ON A.id_programa = C.id_programa  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Programa' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
          + ' 00:00:00'  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk despues de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
          INNER JOIN Efectivas_NoEfectivas ON Efectivas_NoEfectivas.id_tipo_atencion = X.id_tipo_atencion  
                   AND Efectivas_NoEfectivas.id_respuesta_1n = X.id_respuesta_1n  
                   AND Efectivas_NoEfectivas.id_respuesta_2_n = X.id_respuesta_2n  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= Actividad.fecha  
          AND Efectivas_NoEfectivas.efectiva = 1  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk efectivo despues de Web' ,  
       DATEDIFF(HOUR,  
          ( (SELECT  CONTACTENOS_WEB.fecha  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web)  
          ), Actividad.fecha) 'Tiempo de atención Web' ,  
       DATEDIFF(HOUR, Actividad.fecha,  
          ( SELECT TOP 1  
            X.fecha  
            FROM     ( SELECT    A.id_area ,  
               A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      Actividad A WITH ( NOLOCK )  
              UNION  
              SELECT    A.id_area ,  
               A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      ActividadHistoricaSisproven A  
               WITH ( NOLOCK )  
            ) X  
            INNER JOIN Area ON Area.id_area = X.id_area  
            WHERE    X.id_cliente = Actividad.id_cliente  
            AND Area.id_agrupador = @agrupador  
            AND X.id_tipo_atencion = 1  
            AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
            + ' 00:00:00'  
            ORDER BY X.fecha ASC ,  
            X.tipo_tabla DESC  
          )) 'Tiempo de atención TLMK' ,  
       ISNULL(Cliente.referencia, '') 'Referencia' ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       CASE WHEN ISNULL(Actividad.visita_guiada, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Visita Guiada' ,  
       Programacion_Extension.sesion 'Sesión' ,  
       Actividad.tipo_cliente 'Tipo Cliente' ,  
       Actividad.por_descuento 'Descuento' ,  
       CASE WHEN ISNULL(Actividad.monto_matricula, 0) = 1  
         THEN 'SI'  
         ELSE 'NO'  
       END 'Paga Mat.' ,  
       OrigenWeb.origen 'Origen Web' ,  
       CASE WHEN ISNULL(Actividad.con_director, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Atención Acad.' ,  
       ( SELECT TOP 1  
          DIRECTOR_UCAL.director  
         FROM      ActividadDirector  
          INNER JOIN DIRECTOR_UCAL ON ActividadDirector.id_director = DIRECTOR_UCAL.id_director  
         WHERE     ActividadDirector.id_actividad = Actividad.id_actividad  
          AND ActividadDirector.tipo_tabla = Actividad.tipo_tabla  
       ) 'Director Acad.' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE ( SELECT TOP 1  
            P.precio  
          FROM    Programacion_Extension P  
            LEFT JOIN Sede S ON S.id_sede = P.id_sede  
          WHERE   P.id_prog_ext = Actividad.id_prog_ext  
           )  
       END 'Monto' ,  
       ( SELECT TOP 1  
          P.duracion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Duracion ' ,  
       ( SELECT TOP 1  
          S.sede  
         FROM      Programacion_Extension P  
          LEFT JOIN Sede S ON S.id_sede = P.id_sede  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sede Interes' ,  
       ( CASE ( ISNULL(Actividad.monto_matricula, 0) )  
        WHEN 0 THEN 0  
        ELSE ( SELECT TOP 1  
            P.matricula  
            FROM     Programacion_Extension P  
            WHERE    P.id_prog_ext = Actividad.id_prog_ext  
          )  
         END ) 'Matricula' ,  
       ISNULL(Actividad.PagoMatricula, 0) MatriculaPagada ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE CONVERT(DECIMAL(10, 2), ( SELECT TOP 1  
                   P.precio  
                   * P.duracion  
                   - ( ( ( P.precio  
                   * P.duracion )  
                   * ISNULL(Actividad.por_descuento,  
                   0) ) / 100 )  
                FROM  Programacion_Extension P  
                   LEFT JOIN Sede S ON S.id_sede = P.id_sede  
                WHERE P.id_prog_ext = Actividad.id_prog_ext  
                 ))  
       END 'Total' ,  
       ( SELECT TOP 1  
          IdPersona  
         FROM      EMPLID  
         WHERE     IdCliente = Actividad.id_cliente  
       ) AS 'Campus ID' ,  
       ( SELECT TOP 1  
          P.sesion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sesion ' ,  
       CASE WHEN ISNULL(Actividad.anulado, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Venta Anulada'                            
        --  , Programacion_Extension.fecha_inicio 'Fecha Inicio Sesión'                      
       ,  
       CAST(CONVERT(NVARCHAR, Programacion_Extension.fecha_inicio, 103)  
       + ' '  
       + CONVERT(NVARCHAR(5), Programacion_Extension.fecha_inicio, 108) AS SMALLDATETIME) 'Fecha Inicio Sesión' ,  
       ( SELECT TOP 1  
          P.Horario  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Horario' ,  
       Cliente.nro_documento 'DNI' ,  
       CASE WHEN ISNULL(Actividad.VentaV, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Venta Virtual' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
          ), '') codigo_modular--colegio                
       ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
         FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'Cod. Acción Digital',  
         ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'IdChat'  
  
           ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'   
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'      
     FROM    Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
       left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
  
  --select * from Actividad where id_prog_ext <> 0  
       LEFT JOIN Programacion_Extension ON Programacion_Extension.id_prog_ext = Actividad.id_prog_ext  
     -- left join ActividadSede on ActividadSede.id_actividad = Actividad.id_actividad and ActividadSede.tipo_tabla = 1 --Actividad.tipo_tabla  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
       LEFT JOIN OrigenWeb ON OrigenWeb.id_origen = Actividad.id_origen_web  
     WHERE   Actividad.id_actividad IN ( SELECT  #datos.id_actividad  
              FROM    #datos  
              WHERE   tipo_tabla = 1 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        ) 
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
  
     UNION  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) ,  
       Cliente.nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(p.nombre, '')  
          FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono  
       --,case when len(Cliente.celular) > 0 then Cliente.celular else Cliente.celular2 end celular  
       ,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2  
       --,case when len(Cliente.email1) > 0 then Cliente.email1 else Cliente.email2 end email  
       ,  
       TipoAtencion.tipo_atencion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaSisproven am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad_historica  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion  
       -- ,Actividad.fecha  
       ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) fecha  
       --,Actividad.fecha_registro  
       ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND C.id_distrito = D.id_distrito  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) ,  
       Usuario.nombres + ' ' + Usuario.apellidos ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE   Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END ,  
       Actividad.id_actividad_historica ,  
       CASE WHEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '') = ''  
         THEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Usuario.IdSede  
            ), '')  
         ELSE ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '')  
       END Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) 'Condición' ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor'  
       CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
         THEN CASE WHEN ISNULL(Actividad.id_usuario_venta, 0) <> 0  
             THEN ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
               WHERE  UR.id_usuario = Actividad.id_usuario_venta  
                ), '')  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END               
         ELSE ISNULL(( SELECT   UR.nombres + ' '  
              + UR.apellidos  
              FROM     Usuario UR  
              INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
            ), '')  
       END usuarioz ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM      ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ( SELECT    T.tipo_atencion  
         FROM      Actividad_Ultima A  
          INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Útl. Acción' ,  
       ( SELECT    R.respuesta  
        FROM      Actividad_Ultima A  
          INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Últ. Respuesta' ,  
       ( SELECT TOP 1  
          R.respuesta  
         FROM      Actividad_Ultima A  
          LEFT JOIN Respuesta_2_N R ON A.id_respuesta_2n = R.id_respuesta_2_N  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Respuesta 2do Nivel' ,  
       ( SELECT TOP 1  
          A.descripcion  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Observación' ,  
       ( SELECT TOP 1  
          CAST (CONVERT(NVARCHAR, A.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), A.fecha, 108) AS SMALLDATETIME) fecha  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Fecha Útl. Acción' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE ( SELECT TOP 1  
            U.apellidos + ' ' + U.nombres asesor  
          FROM    Actividad_Ultima A  
            INNER JOIN Usuario U ON A.id_usuario = U.id_usuario  
            INNER JOIN Area B ON A.id_area = B.id_area  
          WHERE   A.id_cliente = Cliente.id_cliente  
            AND B.id_agrupador = @agrupador  
           )  
       END AS 'Últ. Asesor' ,  
       ( SELECT TOP 1  
          G.grado_interes  
         FROM      Actividad_Ultima A  
          INNER JOIN GradoInteres G ON A.id_grado = G.id_grado  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Grado Interés' ,  
       ( SELECT TOP 1  
          B.area  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Área' ,  
       ( SELECT TOP 1  
          C.programa  
         FROM      Actividad_Ultima A  
          INNER JOIN Programa C ON A.id_programa = C.id_programa  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Programa' ,  
   --case when Actividad.id_tipo_atencion = 5 then  
   --  case when ISNULL(Actividad.id_contacto_web,0) <> 0 then  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) --  else  
   --    (select top 1 CONTACTENOS_WEB.fecha  
   --    from CONTACTENOS_WEB  
   --    where CONTACTENOS_WEB.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
   --      --and CONTACTENOS_WEB.borrado = 0  
   --      and CONTACTENOS_WEB.fecha < Actividad.fecha  
   --      --and CONTACTENOS_WEB.atendido = 1  
   --      and MONTH(CONTACTENOS_WEB.fecha) between MONTH(Actividad.fecha) - 1 and MONTH(Actividad.fecha)  
   --      and YEAR(CONTACTENOS_WEB.fecha) = YEAR(Actividad.fecha)  
   --      and CONTACTENOS_WEB.id_cliente = Actividad.id_cliente  
   --    order by CONTACTENOS_WEB.fecha desc)  
   --  end  
   --end  
       'Ingreso de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
              A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= Actividad.fecha  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk despues de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
          INNER JOIN Efectivas_NoEfectivas ON Efectivas_NoEfectivas.id_tipo_atencion = X.id_tipo_atencion  
                   AND Efectivas_NoEfectivas.id_respuesta_1n = X.id_respuesta_1n  
                   AND Efectivas_NoEfectivas.id_respuesta_2_n = X.id_respuesta_2n  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
          + ' 00:00:00'  
          AND Efectivas_NoEfectivas.efectiva = 1  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk efectivo despues de Web' ,  
       DATEDIFF(HOUR,  
          ( SELECT   CONTACTENOS_WEB.fecha  
            FROM     CONTACTENOS_WEB  
            WHERE    CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
          ), Actividad.fecha) 'Tiempo de atención Web' ,  
       DATEDIFF(HOUR, Actividad.fecha,  
          ( SELECT TOP 1  
            X.fecha  
            FROM     ( SELECT    A.id_area ,  
               A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      Actividad A WITH ( NOLOCK )  
              UNION  
              SELECT    A.id_area ,  
             A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      ActividadHistoricaSisproven A  
               WITH ( NOLOCK )  
            ) X  
            INNER JOIN Area ON Area.id_area = X.id_area  
            WHERE    X.id_cliente = Actividad.id_cliente  
            AND Area.id_agrupador = @agrupador  
            AND X.id_tipo_atencion = 1  
            AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
            + ' 00:00:00'  
            ORDER BY X.fecha ASC ,  
            X.tipo_tabla DESC  
          )) 'Tiempo de atención TLMK' ,  
       ISNULL(Cliente.referencia, '') ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       CASE WHEN ISNULL(Actividad.visita_guiada, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Visita Guiada' ,  
       Programacion_Extension.sesion 'Sesión' ,  
       Actividad.tipo_cliente 'Tipo Cliente' ,  
       Actividad.por_descuento 'Descuento' ,  
       CASE WHEN ISNULL(Actividad.monto_matricula, 0) = 1  
         THEN 'SI'  
         ELSE 'NO'  
       END 'Paga Mat.' ,  
       OrigenWeb.origen 'Origen Web' ,  
       CASE WHEN ISNULL(Actividad.con_director, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Atención Acad.' ,  
       ( SELECT TOP 1  
          DIRECTOR_UCAL.director  
         FROM      ActividadDirector  
          INNER JOIN DIRECTOR_UCAL ON ActividadDirector.id_director = DIRECTOR_UCAL.id_director  
         WHERE     ActividadDirector.id_actividad = Actividad.id_actividad_historica  
          AND ActividadDirector.tipo_tabla = Actividad.tipo_tabla  
       ) 'Director Acad.' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE ( SELECT TOP 1  
            P.precio  
          FROM    Programacion_Extension P  
            LEFT JOIN Sede S ON S.id_sede = P.id_sede  
          WHERE   P.id_prog_ext = Actividad.id_prog_ext  
           )  
       END 'Monto' ,  
       ( SELECT TOP 1  
          P.duracion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Duracion ' ,  
       ( SELECT TOP 1  
          S.sede  
         FROM      Programacion_Extension P  
         LEFT JOIN Sede S ON S.id_sede = P.id_sede  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sede Interes' ,  
       ( CASE ( ISNULL(Actividad.monto_matricula, 0) )  
        WHEN 0 THEN 0  
        ELSE ( SELECT TOP 1  
            P.matricula  
            FROM     Programacion_Extension P  
            WHERE    P.id_prog_ext = Actividad.id_prog_ext  
          )  
         END ) 'Matricula' ,  
       ISNULL(Actividad.PagoMatricula, 0) MatriculaPagada ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE CONVERT(DECIMAL(10, 2), ( SELECT TOP 1  
                   P.precio  
                   * P.duracion  
                   - ( ( ( P.precio  
                   * P.duracion )  
                   * ISNULL(Actividad.por_descuento,  
                   0) ) / 100 )  
                FROM  Programacion_Extension P  
                   LEFT JOIN Sede S ON S.id_sede = P.id_sede  
                WHERE P.id_prog_ext = Actividad.id_prog_ext  
                 ))  
       END 'Total' ,  
       ( SELECT TOP 1  
          IdPersona  
         FROM      EMPLID  
         WHERE     IdCliente = Actividad.id_cliente  
       ) AS 'Campus ID' ,  
       ( SELECT TOP 1  
          P.sesion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sesion ' ,  
       CASE WHEN ISNULL(Actividad.anulado, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Venta Anulada' ,  
       CAST (CONVERT(NVARCHAR, Programacion_Extension.fecha_inicio, 103)  
       + ' '  
       + CONVERT(NVARCHAR(5), Programacion_Extension.fecha_inicio, 108) AS SMALLDATETIME) 'Fecha Inicio Sesión' ,  
       ( SELECT TOP 1  
          P.Horario  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Horario' ,  
       Cliente.nro_documento 'DNI' ,  
       CASE WHEN ISNULL(Actividad.VentaV, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Venta Virtual' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') codigo_modular ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
          FROM    CONTACTENOS_WEB  
          WHERE  CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'Cod. Acción Digital',  
          ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'IdChat'  
  
                ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
    --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
    --      ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
    --      ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
    --      where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
    --      ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
    --      where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
    --      ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
    --      where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
    --      ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
  
     FROM    ActividadHistoricaSisproven Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
       LEFT JOIN Programacion_Extension ON Programacion_Extension.id_prog_ext = Actividad.id_prog_ext  
         
 left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
       LEFT JOIN OrigenWeb ON OrigenWeb.id_origen = Actividad.id_origen_web  
     WHERE   Actividad.id_actividad_historica IN ( SELECT  
                   id_actividad  
                  FROM  
                   #datos  
                  WHERE  
                   tipo_tabla = 2 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        )  
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
       --                and   isnull(Cliente.sexo,'')  = case(len(@Sexo)) when  0 then ISNULL( Cliente.sexo ,'') else  @sexo end  
   --    and Actividad.id_cliente = 763303  
  
  --     select * from OrigenWeb  
    END  
  
   ELSE  
    BEGIN  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) apellidos ,  
       LTRIM(RTRIM(Cliente.nombres)) nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre distrito ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(p.nombre, '')  
          FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono  
    -- ,case when len(Cliente.celular) > 0 then Cliente.celular else Cliente.celular2 end celular  
       ,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2  
    -- ,case when len(Cliente.email1) > 0 then Cliente.email1 else Cliente.email2 end email  
       ,  
       TipoAtencion.tipo_atencion accion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta respuesta_2_nivel ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaDetalle am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion  
     --,Actividad.fecha fecha_accion  
       ,  
   CAST (CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) AS fecha_accion  
    -- ,Actividad.fecha_registro  
       ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) AS fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND CE.borrado = 0  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) colegio ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND C.id_distrito = D.id_distrito  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND CE.borrado = 0  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) distrito_colegio ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND CE.borrado = 0  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) grado ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
           AND CE.borrado = 0  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) anio_fin ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) periodo ,  
       Usuario.nombres + ' ' + Usuario.apellidos vendedor ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) edad ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil est_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre campania ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE   Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END efec_NoEfect ,  
       Actividad.id_actividad ,  
   ISNULL(( SELECT sede  
          FROM   Sede  
          WHERE  Sede.id_sede = Actividad.id_sede_reg  
           ), '') Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) 'Condición' ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor'  
  
   --,dbo.fn_Asesor_Contacto(Cliente.id_cliente, @agrupador)  'Asesor Contacto'  
       ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
             THEN CASE WHEN ISNULL(Actividad.id_usuario_venta,  
                 0) <> 0  
              THEN ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   WHERE  
                   UR.id_usuario = Actividad.id_usuario_venta  
                 ), '')  
              ELSE ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                 ), '')  
            END       
          
   --isnull((select top 1  UR.nombres + ' ' + UR.apellidos from Usuario UR   where Ur.id_usuario = Actividad.id_usuario_venta),'')  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
       END 'Asesor Contacto' ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM      ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ISNULL(Actividad.fecha_cita, '') 'Fecha Cita' ,  
       ISNULL(Cliente.referencia, '') 'Referencia' ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_ucal  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.id_unidad_negocio = 2  
           AND CE.borrado = 0  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Código Colegio Ucal' ,  
       YEAR(Actividad.fecha) 'Año' ,  
       CASE WHEN MONTH(Actividad.fecha) = 1 THEN 'Enero'  
         WHEN MONTH(Actividad.fecha) = 2 THEN 'Febrero'  
         WHEN MONTH(Actividad.fecha) = 3 THEN 'Marzo'  
         WHEN MONTH(Actividad.fecha) = 4 THEN 'Abril'  
         WHEN MONTH(Actividad.fecha) = 5 THEN 'Mayo'  
         WHEN MONTH(Actividad.fecha) = 6 THEN 'Junio'  
         WHEN MONTH(Actividad.fecha) = 7 THEN 'Julio'  
         WHEN MONTH(Actividad.fecha) = 8 THEN 'Agosto'  
         WHEN MONTH(Actividad.fecha) = 9 THEN 'Septiembre'  
         WHEN MONTH(Actividad.fecha) = 10 THEN 'Octubre'  
         WHEN MONTH(Actividad.fecha) = 11 THEN 'Noviembre'  
         WHEN MONTH(Actividad.fecha) = 12 THEN 'Diciembre'  
       END 'Mes' ,  
       CASE WHEN ISNULL(( SELECT TOP 1  
              CE.anio_fin  
              FROM     ClienteEstudioColegio CE  
              WHERE    CE.id_cliente = Actividad.id_cliente  
              AND CE.id_unidad_negocio = @id_unidad_negocio  
              AND CE.borrado = 0  
            ORDER BY CE.id_cli_est_colegio DESC  
            ), 0) = 0 THEN '5'  
         ELSE ( CASE WHEN ISNULL(( SELECT TOP 1  
                 CE.anio_fin  
                 FROM     ClienteEstudioColegio CE  
                 WHERE    CE.id_cliente = Actividad.id_cliente  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
                 AND CE.borrado = 0  
                 ORDER BY CE.id_cli_est_colegio DESC  
               ), 0) < YEAR(Actividad.fecha)  
            THEN 'Egresado'  
            ELSE STR(5  
               - ( ( SELECT TOP 1  
                 CE.anio_fin  
               FROM    ClienteEstudioColegio CE  
               WHERE   CE.id_cliente = Actividad.id_cliente  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
                 AND CE.borrado = 0  
               ORDER BY CE.id_cli_est_colegio DESC  
                ) - YEAR(Actividad.fecha) ))  
          END )  
       END 'Año Egreso Calulado' ,  
       ( SELECT    CONTACTENOS_WEB.observacion_ventas  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Origen' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          CAST (CONVERT(NVARCHAR, X.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), X.fecha, 108) AS SMALLDATETIME)  
         FROM      ( SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Fecha Primera. Acción' ,  
       ( SELECT TOP 1  
          X.tipo_atencion  
         FROM      ( SELECT    A.* ,  
             T.tipo_atencion  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.* ,  
             T.tipo_atencion  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera . Acción' ,  
       ( SELECT TOP 1  
          X.respuesta  
         FROM      ( SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera. Respuesta' ,  
       CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
         THEN ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              WHERE    UR.id_usuario = Actividad.id_usuario_venta  
            ), '')  
         ELSE ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
            ), '')  
       END AS Usuario ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') codigo_modular ,  
       ( SELECT    motivo_devolucion  
       FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
          FROM    CONTACTENOS_WEB  
         WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'Cod. Acción Digital' ,   
           ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'IdChat'    
  
                  ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
  
 --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
 --         ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
 --         ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
 --         ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
 --         ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
 --         ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
     FROM    Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
         
 left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
   --left join ActividadSede on ActividadSede.id_actividad = Actividad.id_actividad and ActividadSede.tipo_tabla = 1 --Actividad.tipo_tabla  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
     WHERE   Actividad.id_actividad IN ( SELECT  #datos.id_actividad  
              FROM    #datos  
              WHERE   tipo_tabla = 1 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        )
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
  ---    and   isnull(Cliente.sexo,'')  = case(len(@Sexo)) when  0 then ISNULL( Cliente.sexo ,'') else  @sexo end  
     UNION  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) ,  
       Cliente.nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(p.nombre, '')  
          FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono  
     --,case when len(Cliente.celular) > 0 then Cliente.celular else Cliente.celular2 end celular  
       ,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2  
     --,case when len(Cliente.email1) > 0 then Cliente.email1 else Cliente.email2 end email  
       ,  
       TipoAtencion.tipo_atencion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaSisproven am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad_historica  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) AS fecha  
    -- ,Actividad.fecha_registro                                                             
       ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) AS fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND C.id_distrito = D.id_distrito  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) ,  
       Usuario.nombres + ' ' + Usuario.apellidos ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE   Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END ,  
       Actividad.id_actividad_historica ,  
       ISNULL(( SELECT sede  
          FROM   Sede  
          WHERE  Sede.id_sede = Actividad.id_sede_reg  
           ), '') Sede ,  
       ISNULL(Sede.sede, '') SedeInteres,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor'  
  
   --,dbo.fn_Asesor_Contacto(Cliente.id_cliente, @agrupador)  usuario  
       ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
             THEN CASE WHEN ISNULL(Actividad.id_usuario_venta,  
                 0) <> 0  
              THEN ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   WHERE  
                   UR.id_usuario = Actividad.id_usuario_venta  
                 ), '')  
              ELSE ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                 ), '')  
            END       
   --isnull((select top 1  UR.nombres + ' ' + UR.apellidos from Usuario UR   where Ur.id_usuario = Actividad.id_usuario_venta),'')            
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
       END usuario ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM  ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ISNULL(Actividad.fecha_cita, '') 'Fecha Cita' ,  
       ISNULL(Cliente.referencia, '') 'Referencia' ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_ucal  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Código Colegio Ucal' ,  
       YEAR(Actividad.fecha) 'Año' ,  
       CASE WHEN MONTH(Actividad.fecha) = 1 THEN 'Enero'  
         WHEN MONTH(Actividad.fecha) = 2 THEN 'Febrero'  
         WHEN MONTH(Actividad.fecha) = 3 THEN 'Marzo'  
         WHEN MONTH(Actividad.fecha) = 4 THEN 'Abril'  
         WHEN MONTH(Actividad.fecha) = 5 THEN 'Mayo'  
         WHEN MONTH(Actividad.fecha) = 6 THEN 'Junio'  
         WHEN MONTH(Actividad.fecha) = 7 THEN 'Julio'  
         WHEN MONTH(Actividad.fecha) = 8 THEN 'Agosto'  
         WHEN MONTH(Actividad.fecha) = 9 THEN 'Septiembre'  
         WHEN MONTH(Actividad.fecha) = 10 THEN 'Octubre'  
         WHEN MONTH(Actividad.fecha) = 11 THEN 'Noviembre'  
         WHEN MONTH(Actividad.fecha) = 12 THEN 'Diciembre'  
       END 'Mes' ,  
       CASE WHEN ISNULL(( SELECT TOP 1  
              CE.anio_fin  
              FROM     ClienteEstudioColegio CE  
              WHERE    CE.id_cliente = Actividad.id_cliente  
              AND CE.borrado = 0  
              AND CE.id_unidad_negocio = @id_unidad_negocio  
              ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) = 0 THEN '5'  
         ELSE ( CASE WHEN ISNULL(( SELECT TOP 1  
                 CE.anio_fin  
                 FROM     ClienteEstudioColegio CE  
                 WHERE    CE.id_cliente = Actividad.id_cliente  
                 AND CE.borrado = 0  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
                 ORDER BY CE.id_cli_est_colegio DESC  
               ), 0) < YEAR(Actividad.fecha)  
            THEN 'Egresado'  
            ELSE STR(5  
               - ( ( SELECT TOP 1  
                 CE.anio_fin  
               FROM    ClienteEstudioColegio CE  
               WHERE   CE.id_cliente = Actividad.id_cliente  
                 AND CE.borrado = 0  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
               ORDER BY CE.id_cli_est_colegio DESC  
                ) - YEAR(Actividad.fecha) ))  
          END )  
       END ,  
       ( SELECT    CONTACTENOS_WEB.observacion_ventas  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Origen' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          CAST (CONVERT(NVARCHAR, X.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), X.fecha, 108) AS SMALLDATETIME)  --X.fecha  
         FROM      ( SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Fecha Primera. Acción' ,  
       ( SELECT TOP 1  
          X.tipo_atencion  
         FROM      ( SELECT    A.* ,  
             T.tipo_atencion  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.* ,  
             T.tipo_atencion  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera . Acción' ,  
       ( SELECT TOP 1  
          X.respuesta  
         FROM      ( SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera. Respuesta'  
    --         ,                                             
    --                        isnull((select UR.usuario from Usuario UR inner join ClienteAsesorID on UR.id_usuario = ClienteAsesorID.id_usuario  
    --and ClienteAsesorID.id_cliente = Cliente.id_cliente  
    --and ClienteAsesorID.id_agrupador = Area.id_agrupador),'')    as Usuario  
       ,  
       CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
         THEN ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              WHERE    UR.id_usuario = Actividad.id_usuario_venta  
            ), '')  
         ELSE ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
            ), '')  
       END AS Usuario ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') codigo_modular ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
        )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'Cod. Acción Digital',  
         ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'IdChat'  
  
                  ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
  
 --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
 --         ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
 --         ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
 --         ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
 --         ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
 --         ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
     FROM    ActividadHistoricaSisproven Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
         
 left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
   --  left join ActividadSede on ActividadSede.id_actividad = Actividad.id_actividad_historica and ActividadSede.tipo_tabla = 2  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
    --  inner join ClienteAsesorID on ClienteAsesorID.id_cliente = Cliente.id_cliente  
     WHERE   Actividad.id_actividad_historica IN ( SELECT  
                   id_actividad  
                  FROM  
                   #datos  
                  WHERE  
                   tipo_tabla = 2 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        )  
	   AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
    --   and Area.id_agrupador = ClienteAsesorID.id_agrupador  
  
    --and   isnull(Cliente.sexo,'')  = case(len(@Sexo)) when  0 then ISNULL( Cliente.sexo ,'') else  @sexo end  
  
    END  
  END  
  
 ELSE  
  
  BEGIN      
   IF @accion IN ( '8', '6', '7', '11', '2', '3', '12', '15', '9', '4', '5',  
       '55', '10' )  
    BEGIN  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) apellidos ,  
       LTRIM(RTRIM(Cliente.nombres)) nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre distrito ,  
       ISNULL(( SELECT TOP ( 1 )  
       ISNULL(p.nombre, '')  
       FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2,  
       TipoAtencion.tipo_atencion accion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta respuesta_2_nivel ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaDetalle am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion,  
       CAST(CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) fecha_accion,  
       CAST(CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) colegio ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND C.id_distrito = D.id_distrito  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
        ORDER BY  CE.id_cli_est_colegio DESC  
        ) distrito_colegio ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) grado ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) anio_fin ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) periodo ,  
       Usuario.nombres + ' ' + Usuario.apellidos vendedor ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) edad ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil est_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre campania ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE   Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END efec_NoEfect ,  
       Actividad.id_actividad ,  
       CASE WHEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '') = ''  
         THEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Usuario.IdSede  
            ), '')  
         ELSE ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '')  
       END Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) 'Condición' ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor',  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
             THEN CASE WHEN ISNULL(Actividad.id_usuario_venta,  
                 0) <> 0  
              THEN ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   WHERE  
                   UR.id_usuario = Actividad.id_usuario_venta  
                 ), '')  
              ELSE ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                 ), '')  
            END  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
       END 'Asesor Contacto' ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM      ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ( SELECT    T.tipo_atencion  
         FROM      Actividad_Ultima A  
          INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Útl. Acción' ,  
       ( SELECT    R.respuesta  
         FROM      Actividad_Ultima A  
          INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Últ. Respuesta' ,  
       ( SELECT TOP 1  
          R.respuesta  
         FROM      Actividad_Ultima A  
          LEFT JOIN Respuesta_2_N R ON A.id_respuesta_2n = R.id_respuesta_2_N  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Respuesta 2do Nivel' ,  
       ( SELECT TOP 1  
          A.descripcion  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Observación' ,  
       ( SELECT TOP 1  
          CAST(CONVERT(NVARCHAR, A.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), A.fecha, 108) AS SMALLDATETIME) fecha  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Fecha Útl. Acción' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE ( SELECT TOP 1  
            U.apellidos + ' ' + U.nombres asesor  
          FROM    Actividad_Ultima A  
            INNER JOIN Usuario U ON A.id_usuario = U.id_usuario  
            INNER JOIN Area B ON A.id_area = B.id_area  
          WHERE   A.id_cliente = Cliente.id_cliente  
            AND B.id_agrupador = @agrupador  
           )  
       END AS 'Últ. Asesor' ,  
       ( SELECT TOP 1  
          G.grado_interes  
         FROM      Actividad_Ultima A  
          INNER JOIN GradoInteres G ON A.id_grado = G.id_grado  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Grado Interés' ,  
       ( SELECT TOP 1  
          B.area  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Área' ,  
       ( SELECT TOP 1  
          C.programa  
         FROM      Actividad_Ultima A  
          INNER JOIN Programa C ON A.id_programa = C.id_programa  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Programa' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
          + ' 00:00:00'  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk despues de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
          INNER JOIN Efectivas_NoEfectivas ON Efectivas_NoEfectivas.id_tipo_atencion = X.id_tipo_atencion  
                   AND Efectivas_NoEfectivas.id_respuesta_1n = X.id_respuesta_1n  
                   AND Efectivas_NoEfectivas.id_respuesta_2_n = X.id_respuesta_2n  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= Actividad.fecha  
          AND Efectivas_NoEfectivas.efectiva = 1  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk efectivo despues de Web' ,  
       DATEDIFF(HOUR,  
          ( (SELECT  CONTACTENOS_WEB.fecha  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web)  
          ), Actividad.fecha) 'Tiempo de atención Web' ,  
       DATEDIFF(HOUR, Actividad.fecha,  
          ( SELECT TOP 1  
            X.fecha  
            FROM     ( SELECT    A.id_area ,  
               A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      Actividad A WITH ( NOLOCK )  
              UNION  
              SELECT    A.id_area ,  
               A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      ActividadHistoricaSisproven A  
               WITH ( NOLOCK )  
            ) X  
            INNER JOIN Area ON Area.id_area = X.id_area  
            WHERE    X.id_cliente = Actividad.id_cliente  
            AND Area.id_agrupador = @agrupador  
            AND X.id_tipo_atencion = 1  
            AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
            + ' 00:00:00'  
            ORDER BY X.fecha ASC ,  
            X.tipo_tabla DESC  
          )) 'Tiempo de atención TLMK' ,  
       ISNULL(Cliente.referencia, '') 'Referencia' ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       CASE WHEN ISNULL(Actividad.visita_guiada, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Visita Guiada' ,  
       Programacion_Extension.sesion 'Sesión' ,  
       Actividad.tipo_cliente 'Tipo Cliente' ,  
       Actividad.por_descuento 'Descuento' ,  
       CASE WHEN ISNULL(Actividad.monto_matricula, 0) = 1  
         THEN 'SI'  
         ELSE 'NO'  
       END 'Paga Mat.' ,  
       OrigenWeb.origen 'Origen Web' ,  
       CASE WHEN ISNULL(Actividad.con_director, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Atención Acad.' ,  
       ( SELECT TOP 1  
          DIRECTOR_UCAL.director  
         FROM      ActividadDirector  
          INNER JOIN DIRECTOR_UCAL ON ActividadDirector.id_director = DIRECTOR_UCAL.id_director  
         WHERE     ActividadDirector.id_actividad = Actividad.id_actividad  
          AND ActividadDirector.tipo_tabla = Actividad.tipo_tabla  
       ) 'Director Acad.' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE ( SELECT TOP 1  
            P.precio  
          FROM    Programacion_Extension P  
            LEFT JOIN Sede S ON S.id_sede = P.id_sede  
          WHERE   P.id_prog_ext = Actividad.id_prog_ext  
           )  
       END 'Monto' ,  
       ( SELECT TOP 1  
          P.duracion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Duracion ' ,  
       ( SELECT TOP 1  
          S.sede  
         FROM      Programacion_Extension P  
          LEFT JOIN Sede S ON S.id_sede = P.id_sede  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sede Interes' ,  
       ( CASE ( ISNULL(Actividad.monto_matricula, 0) )  
        WHEN 0 THEN 0  
        ELSE ( SELECT TOP 1  
            P.matricula  
            FROM     Programacion_Extension P  
            WHERE    P.id_prog_ext = Actividad.id_prog_ext  
          )  
         END ) 'Matricula' ,  
       ISNULL(Actividad.PagoMatricula, 0) MatriculaPagada ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE CONVERT(DECIMAL(10, 2), ( SELECT TOP 1  
                   P.precio  
                   * P.duracion  
                   - ( ( ( P.precio  
                   * P.duracion )  
                   * ISNULL(Actividad.por_descuento,  
                   0) ) / 100 )  
                FROM  Programacion_Extension P  
                   LEFT JOIN Sede S ON S.id_sede = P.id_sede  
                WHERE P.id_prog_ext = Actividad.id_prog_ext  
                 ))  
       END 'Total' ,  
       ( SELECT TOP 1  
          IdPersona  
         FROM      EMPLID  
         WHERE     IdCliente = Actividad.id_cliente  
       ) AS 'Campus ID' ,  
       ( SELECT TOP 1  
          P.sesion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sesion ' ,  
       CASE WHEN ISNULL(Actividad.anulado, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Venta Anulada',  
       CAST(CONVERT(NVARCHAR, Programacion_Extension.fecha_inicio, 103)  
       + ' '  
       + CONVERT(NVARCHAR(5), Programacion_Extension.fecha_inicio, 108) AS SMALLDATETIME) 'Fecha Inicio Sesión' ,  
       ( SELECT TOP 1  
          P.Horario  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Horario' ,  
       Cliente.nro_documento 'DNI' ,  
       CASE WHEN ISNULL(Actividad.VentaV, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Venta Virtual' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
          ), '') codigo_modular--colegio                
       ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe            WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
         FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'Cod. Acción Digital',  
         ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
            ), '') 'IdChat'  
  
                   ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
      --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
      --    ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
      --    ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
      --    where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
      --    ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
      --    where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
      --    ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
      --    where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
      --    ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
     FROM    Actividad_Ultima Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
       LEFT JOIN Programacion_Extension ON Programacion_Extension.id_prog_ext = Actividad.id_prog_ext  
         
 left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
       LEFT JOIN OrigenWeb ON OrigenWeb.id_origen = Actividad.id_origen_web  
     WHERE   Actividad.id_actividad IN ( SELECT  #datos.id_actividad  
              FROM    #datos  
              WHERE   tipo_tabla = 1 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        )  
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
     UNION  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) ,  
       Cliente.nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(p.nombre, '')  
          FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2,  
       TipoAtencion.tipo_atencion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaSisproven am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad_historica  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) fecha,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND C.id_distrito = D.id_distrito  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) ,  
       Usuario.nombres + ' ' + Usuario.apellidos ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE  Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END ,  
       Actividad.id_actividad_historica ,  
       CASE WHEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '') = ''  
         THEN ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Usuario.IdSede  
            ), '')  
         ELSE ISNULL(( SELECT   sede  
              FROM     Sede  
              WHERE    Sede.id_sede = Actividad.id_sede_reg  
            ), '')  
       END Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) 'Condición' ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor',   
       CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
         THEN CASE WHEN ISNULL(Actividad.id_usuario_venta, 0) <> 0  
             THEN ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
               WHERE  UR.id_usuario = Actividad.id_usuario_venta  
                ), '')  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
         ELSE ISNULL(( SELECT   UR.nombres + ' '  
              + UR.apellidos  
              FROM     Usuario UR  
              INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
            ), '')  
       END usuarioz ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM      ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ( SELECT    T.tipo_atencion  
         FROM      Actividad_Ultima A  
          INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Útl. Acción' ,  
       ( SELECT    R.respuesta  
         FROM      Actividad_Ultima A  
          INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Últ. Respuesta' ,  
       ( SELECT TOP 1  
          R.respuesta  
         FROM      Actividad_Ultima A  
          LEFT JOIN Respuesta_2_N R ON A.id_respuesta_2n = R.id_respuesta_2_N  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Respuesta 2do Nivel' ,  
       ( SELECT TOP 1  
          A.descripcion  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Observación' ,  
       ( SELECT TOP 1  
          CAST (CONVERT(NVARCHAR, A.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), A.fecha, 108) AS SMALLDATETIME) fecha  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Fecha Útl. Acción' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE ( SELECT TOP 1  
            U.apellidos + ' ' + U.nombres asesor  
          FROM    Actividad_Ultima A  
            INNER JOIN Usuario U ON A.id_usuario = U.id_usuario  
            INNER JOIN Area B ON A.id_area = B.id_area  
          WHERE   A.id_cliente = Cliente.id_cliente  
            AND B.id_agrupador = @agrupador  
           )  
       END AS 'Últ. Asesor' ,  
       ( SELECT TOP 1  
          G.grado_interes  
         FROM      Actividad_Ultima A  
          INNER JOIN GradoInteres G ON A.id_grado = G.id_grado  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Grado Interés' ,  
       ( SELECT TOP 1  
          B.area  
         FROM      Actividad_Ultima A  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Área' ,  
       ( SELECT TOP 1  
          C.programa  
         FROM      Actividad_Ultima A  
          INNER JOIN Programa C ON A.id_programa = C.id_programa  
          INNER JOIN Area B ON A.id_area = B.id_area  
         WHERE     A.id_cliente = Cliente.id_cliente  
          AND B.id_agrupador = @agrupador  
       ) AS 'Programa' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) AS 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
              A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= Actividad.fecha  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk despues de Web' ,  
       ( SELECT TOP 1  
          X.fecha  
         FROM      ( SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      Actividad A WITH ( NOLOCK )  
            UNION  
            SELECT    A.id_area ,  
             A.id_cliente ,  
             A.id_tipo_atencion ,  
             A.fecha ,  
             A.tipo_tabla ,  
             A.id_respuesta_1n ,  
             A.id_respuesta_2n  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
          ) X  
          INNER JOIN Area ON Area.id_area = X.id_area  
          INNER JOIN Efectivas_NoEfectivas ON Efectivas_NoEfectivas.id_tipo_atencion = X.id_tipo_atencion  
                   AND Efectivas_NoEfectivas.id_respuesta_1n = X.id_respuesta_1n  
                   AND Efectivas_NoEfectivas.id_respuesta_2_n = X.id_respuesta_2n  
         WHERE     X.id_cliente = Actividad.id_cliente  
          AND Area.id_agrupador = @agrupador  
          AND X.id_tipo_atencion = 1  
          AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
          + ' 00:00:00'  
          AND Efectivas_NoEfectivas.efectiva = 1  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla DESC  
       ) '1er tlmk efectivo despues de Web' ,  
       DATEDIFF(HOUR,  
          ( SELECT   CONTACTENOS_WEB.fecha  
            FROM     CONTACTENOS_WEB  
            WHERE    CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
          ), Actividad.fecha) 'Tiempo de atención Web' ,  
       DATEDIFF(HOUR, Actividad.fecha,  
          ( SELECT TOP 1  
            X.fecha  
            FROM     ( SELECT    A.id_area ,  
               A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
             A.tipo_tabla  
              FROM      Actividad A WITH ( NOLOCK )  
              UNION  
              SELECT    A.id_area ,  
             A.id_cliente ,  
               A.id_tipo_atencion ,  
               A.fecha ,  
               A.tipo_tabla  
              FROM      ActividadHistoricaSisproven A  
               WITH ( NOLOCK )  
            ) X  
            INNER JOIN Area ON Area.id_area = X.id_area  
            WHERE    X.id_cliente = Actividad.id_cliente  
            AND Area.id_agrupador = @agrupador  
            AND X.id_tipo_atencion = 1  
            AND X.fecha >= CONVERT(VARCHAR(10), Actividad.fecha, 103)  
            + ' 00:00:00'  
            ORDER BY X.fecha ASC ,  
            X.tipo_tabla DESC  
          )) 'Tiempo de atención TLMK' ,  
       ISNULL(Cliente.referencia, '') ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       CASE WHEN ISNULL(Actividad.visita_guiada, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Visita Guiada' ,  
       Programacion_Extension.sesion 'Sesión' ,  
       Actividad.tipo_cliente 'Tipo Cliente' ,  
       Actividad.por_descuento 'Descuento' ,  
       CASE WHEN ISNULL(Actividad.monto_matricula, 0) = 1  
         THEN 'SI'  
         ELSE 'NO'  
       END 'Paga Mat.' ,  
       OrigenWeb.origen 'Origen Web' ,  
       CASE WHEN ISNULL(Actividad.con_director, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Atención Acad.' ,  
       ( SELECT TOP 1  
          DIRECTOR_UCAL.director  
         FROM      ActividadDirector  
          INNER JOIN DIRECTOR_UCAL ON ActividadDirector.id_director = DIRECTOR_UCAL.id_director  
         WHERE     ActividadDirector.id_actividad = Actividad.id_actividad_historica  
          AND ActividadDirector.tipo_tabla = Actividad.tipo_tabla  
       ) 'Director Acad.' ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE ( SELECT TOP 1  
            P.precio  
          FROM    Programacion_Extension P  
            LEFT JOIN Sede S ON S.id_sede = P.id_sede  
          WHERE   P.id_prog_ext = Actividad.id_prog_ext  
           )  
       END 'Monto' ,  
       ( SELECT TOP 1  
          P.duracion  
          FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Duracion ' ,  
       ( SELECT TOP 1  
          S.sede  
         FROM      Programacion_Extension P  
         LEFT JOIN Sede S ON S.id_sede = P.id_sede  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sede Interes' ,  
       ( CASE ( ISNULL(Actividad.monto_matricula, 0) )  
        WHEN 0 THEN 0  
        ELSE ( SELECT TOP 1  
            P.matricula  
            FROM     Programacion_Extension P  
            WHERE    P.id_prog_ext = Actividad.id_prog_ext  
          )  
         END ) 'Matricula' ,  
       ISNULL(Actividad.PagoMatricula, 0) MatriculaPagada ,  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN 0  
         ELSE CONVERT(DECIMAL(10, 2), ( SELECT TOP 1  
                   P.precio  
                   * P.duracion  
                   - ( ( ( P.precio  
                   * P.duracion )  
                   * ISNULL(Actividad.por_descuento,  
                   0) ) / 100 )  
                FROM  Programacion_Extension P  
                   LEFT JOIN Sede S ON S.id_sede = P.id_sede  
                WHERE P.id_prog_ext = Actividad.id_prog_ext  
                 ))  
       END 'Total' ,  
       ( SELECT TOP 1  
          IdPersona  
         FROM      EMPLID  
         WHERE     IdCliente = Actividad.id_cliente  
       ) AS 'Campus ID' ,  
       ( SELECT TOP 1  
          P.sesion  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Sesion ' ,  
       CASE WHEN ISNULL(Actividad.anulado, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Venta Anulada' ,  
       CAST (CONVERT(NVARCHAR, Programacion_Extension.fecha_inicio, 103)  
       + ' '  
       + CONVERT(NVARCHAR(5), Programacion_Extension.fecha_inicio, 108) AS SMALLDATETIME) 'Fecha Inicio Sesión' ,  
       ( SELECT TOP 1  
          P.Horario  
         FROM      Programacion_Extension P  
         WHERE     P.id_prog_ext = Actividad.id_prog_ext  
       ) 'Horario' ,  
       Cliente.nro_documento 'DNI' ,  
       CASE WHEN ISNULL(Actividad.VentaV, 0) = 0 THEN 'NO'  
         ELSE 'SI'  
       END 'Venta Virtual' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') codigo_modular ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
          FROM    CONTACTENOS_WEB  
          WHERE  CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'Cod. Acción Digital',  
          ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'IdChat'  
                  ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
 --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
 --         ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
 --         ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
 --         ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
 --         ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
 --         ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
     FROM    ActividadHistoricaSisproven Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
       LEFT JOIN Programacion_Extension ON Programacion_Extension.id_prog_ext = Actividad.id_prog_ext  
         
 left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
       LEFT JOIN OrigenWeb ON OrigenWeb.id_origen = Actividad.id_origen_web  
     WHERE   Actividad.id_actividad_historica IN ( SELECT  
                   id_actividad  
                  FROM  
                   #datos  
                  WHERE  
                   tipo_tabla = 2 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        ) 
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
    END  
   ELSE  
    BEGIN  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) apellidos ,  
       LTRIM(RTRIM(Cliente.nombres)) nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre distrito ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(p.nombre, '')  
          FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2,  
       TipoAtencion.tipo_atencion accion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta respuesta_2_nivel ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaDetalle am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) AS fecha_accion,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) AS fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND CE.borrado = 0  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) colegio ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND C.id_distrito = D.id_distrito  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND CE.borrado = 0  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) distrito_colegio ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND CE.borrado = 0  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) grado ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
           AND CE.borrado = 0  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) anio_fin ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) periodo ,  
       Usuario.nombres + ' ' + Usuario.apellidos vendedor ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) edad ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil est_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre campania ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE   Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END efec_NoEfect ,  
       Actividad.id_actividad ,  
       ISNULL(( SELECT sede  
          FROM   Sede  
          WHERE  Sede.id_sede = Actividad.id_sede_reg  
           ), '') Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) 'Condición' ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor',  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
             THEN CASE WHEN ISNULL(Actividad.id_usuario_venta,  
                 0) <> 0  
              THEN ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   WHERE  
                   UR.id_usuario = Actividad.id_usuario_venta  
                 ), '')  
              ELSE ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                 ), '')  
            END  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
       END 'Asesor Contacto' ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM      ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ISNULL(Actividad.fecha_cita, '') 'Fecha Cita' ,  
       ISNULL(Cliente.referencia, '') 'Referencia' ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_ucal  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.id_unidad_negocio = 2  
           AND CE.borrado = 0  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Código Colegio Ucal' ,  
       YEAR(Actividad.fecha) 'Año' ,  
       CASE WHEN MONTH(Actividad.fecha) = 1 THEN 'Enero'  
         WHEN MONTH(Actividad.fecha) = 2 THEN 'Febrero'  
         WHEN MONTH(Actividad.fecha) = 3 THEN 'Marzo'  
         WHEN MONTH(Actividad.fecha) = 4 THEN 'Abril'  
         WHEN MONTH(Actividad.fecha) = 5 THEN 'Mayo'  
         WHEN MONTH(Actividad.fecha) = 6 THEN 'Junio'  
         WHEN MONTH(Actividad.fecha) = 7 THEN 'Julio'  
         WHEN MONTH(Actividad.fecha) = 8 THEN 'Agosto'  
         WHEN MONTH(Actividad.fecha) = 9 THEN 'Septiembre'  
         WHEN MONTH(Actividad.fecha) = 10 THEN 'Octubre'  
         WHEN MONTH(Actividad.fecha) = 11 THEN 'Noviembre'  
         WHEN MONTH(Actividad.fecha) = 12 THEN 'Diciembre'  
       END 'Mes' ,  
       CASE WHEN ISNULL(( SELECT TOP 1  
              CE.anio_fin  
              FROM     ClienteEstudioColegio CE  
              WHERE    CE.id_cliente = Actividad.id_cliente  
              AND CE.id_unidad_negocio = @id_unidad_negocio  
              AND CE.borrado = 0  
            ORDER BY CE.id_cli_est_colegio DESC  
            ), 0) = 0 THEN '5'  
         ELSE ( CASE WHEN ISNULL(( SELECT TOP 1  
                 CE.anio_fin  
                 FROM     ClienteEstudioColegio CE  
                 WHERE    CE.id_cliente = Actividad.id_cliente  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
                 AND CE.borrado = 0  
                 ORDER BY CE.id_cli_est_colegio DESC  
               ), 0) < YEAR(Actividad.fecha)  
            THEN 'Egresado'  
            ELSE STR(5  
               - ( ( SELECT TOP 1  
                 CE.anio_fin  
               FROM    ClienteEstudioColegio CE  
               WHERE   CE.id_cliente = Actividad.id_cliente  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
                 AND CE.borrado = 0  
               ORDER BY CE.id_cli_est_colegio DESC  
                ) - YEAR(Actividad.fecha) ))  
          END )  
       END 'Año Egreso Calulado' ,  
       ( SELECT    CONTACTENOS_WEB.observacion_ventas  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Origen' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          CAST (CONVERT(NVARCHAR, X.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), X.fecha, 108) AS SMALLDATETIME)  
         FROM      ( SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Fecha Primera. Acción' ,  
       ( SELECT TOP 1  
          X.tipo_atencion  
         FROM      ( SELECT    A.* ,  
             T.tipo_atencion  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
              AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.* ,  
             T.tipo_atencion  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera . Acción' ,  
       ( SELECT TOP 1  
          X.respuesta  
         FROM      ( SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera. Respuesta' ,  
       CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
         THEN ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              WHERE    UR.id_usuario = Actividad.id_usuario_venta  
            ), '')  
         ELSE ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
            ), '')  
       END AS Usuario ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') codigo_modular ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
          FROM    CONTACTENOS_WEB  
         WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'Cod. Acción Digital' ,   
           ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad  
           ), '') 'IdChat'  
  
                  ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
  --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
  --        ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
  --        ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
  --        where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
  --        ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
  --        where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
  --        ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
  --        where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
  --        ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
     FROM    Actividad_Ultima Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
         
	   left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
     WHERE   Actividad.id_actividad IN ( SELECT  #datos.id_actividad  
              FROM    #datos  
              WHERE   tipo_tabla = 1 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        )
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )

     UNION  
     SELECT  Cliente.id_cliente ,  
       LTRIM(RTRIM(Cliente.apellido_paterno)) + ' '  
       + LTRIM(RTRIM(Cliente.apellido_materno)) ,  
       Cliente.nombres ,  
       CASE ( ISNULL(Cliente.sexo, '') )  
         WHEN 'F' THEN 'Femenino'  
         WHEN 'M' THEN 'Masculino'  
       END AS Sexo ,  
       Cliente.direccion ,  
       Distrito.nombre ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(p.nombre, '')  
          FROM   Provincia p  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Provincia' ,  
       ISNULL(( SELECT TOP ( 1 )  
           ISNULL(d.nombre, '')  
          FROM   Provincia p  
           INNER JOIN Departamento d ON p.id_departamento = d.id_departamento  
          WHERE  p.id_provincia = Distrito.id_provincia  
           ), '') 'Departamento' ,  
       Cliente.telefono ,  
       ISNULL(Cliente.celular, '') celular ,  
       ISNULL(Cliente.celular2, '') celular2 ,  
       ISNULL(Cliente.email1, '') email1 ,  
       ISNULL(Cliente.email2, '') email2,  
       TipoAtencion.tipo_atencion ,  
       Respuesta_1_N.respuesta ,  
       Respuesta_2_N.respuesta ,  
       ( SELECT    STUFF(( SELECT  ', ' + mi.medio_informa  
            FROM    ActividadMedioInformaSisproven am  
              INNER JOIN MedioInforma mi ON am.id_medio_informa = mi.id_medio_informa  
            WHERE   id_actividad = Actividad.id_actividad_historica  
              AND id_cliente = Actividad.id_cliente  
             FOR  
            XML PATH('')  
             ), 1, 1, '')  
       ) AS medio_informa ,  
       Actividad.descripcion ,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha, 103) + ' '  
       + CONVERT(NVARCHAR(5), Actividad.fecha, 108) AS SMALLDATETIME) AS fecha,  
       CAST (CONVERT(NVARCHAR, Actividad.fecha_registro, 103)  
       + ' ' + CONVERT(NVARCHAR(5), Actividad.fecha_registro, 108) AS SMALLDATETIME) AS fecha_registro ,  
       Area.area ,  
       Programa.programa ,  
       Curso.curso ,  
       ( SELECT TOP 1  
          C.colegio  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          D.nombre  
         FROM      ClienteEstudioColegio CE ,  
          Colegio C ,  
          Distrito D  
         WHERE     CE.id_colegio = C.id_colegio  
          AND CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
          AND C.id_distrito = D.id_distrito  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ( SELECT TOP 1  
          CE.grado_estudio  
         FROM      ClienteEstudioColegio CE  
         WHERE     CE.id_cliente = Actividad.id_cliente  
          AND CE.borrado = 0  
          AND CE.id_unidad_negocio = @id_unidad_negocio  
         ORDER BY  CE.id_cli_est_colegio DESC  
       ) ,  
       ISNULL(( SELECT TOP 1  
           CE.anio_fin  
          FROM   ClienteEstudioColegio CE  
          WHERE  CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) ,  
       ( SELECT    P.periodo  
         FROM      Periodo P  
         WHERE     P.id_periodo = Campania.id_periodo  
       ) ,  
       Usuario.nombres + ' ' + Usuario.apellidos ,  
       ( CASE WHEN YEAR(Cliente.fecha_nacimiento) > 1900  
           THEN YEAR(GETDATE())  
          - YEAR(Cliente.fecha_nacimiento)  
           ELSE ''  
         END ) ,  
       Profesion.profesion ,  
       EstadoCivil.estado_civil ,  
       Nacionalidad.nacionalidad ,  
       Campania.nombre ,  
       UnidadNegocio.unidad_negocio ,  
       CASE WHEN ( SELECT  efectiva  
          FROM    Efectivas_NoEfectivas  
          WHERE   Efectivas_NoEfectivas.id_respuesta_1n = Actividad.id_respuesta_1n  
            AND Efectivas_NoEfectivas.id_respuesta_2_n = Actividad.id_respuesta_2n  
           ) = 1 THEN 'EFECTIVA'  
         ELSE 'NO EFECTIVA'  
       END ,  
       Actividad.id_actividad_historica ,  
       ISNULL(( SELECT sede  
          FROM   Sede  
          WHERE  Sede.id_sede = Actividad.id_sede_reg  
           ), '') Sede ,  
       ISNULL(Sede.sede, '') SedeInteres ,  
       dbo.fn_Contacto_Condicion(Cliente.id_cliente, @id_campania) ,  
       ( SELECT    nombre_evento  
         FROM      Evento  
         WHERE     Evento.id_evento = Actividad.id_evento  
       ) 'Evento' ,  
       ( SELECT    promotor  
         FROM      PromotorColegio  
         WHERE     PromotorColegio.id_promotor_colegio = Actividad.id_promotor_colegio  
       ) 'Promotor',  
       CASE WHEN ( Actividad.tipo_cliente ) = 'B' THEN ''  
         ELSE CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
             THEN CASE WHEN ISNULL(Actividad.id_usuario_venta,  
                 0) <> 0  
              THEN ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   WHERE  
                   UR.id_usuario = Actividad.id_usuario_venta  
                 ), '')  
              ELSE ISNULL(( SELECT TOP 1  
                   UR.nombres + ' '  
                   + UR.apellidos  
                   FROM  
                   Usuario UR  
                   INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                 ), '')  
            END  
             ELSE ISNULL(( SELECT TOP 1  
                UR.nombres + ' '  
                + UR.apellidos  
               FROM   Usuario UR  
                INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
                ), '')  
           END  
       END usuario ,  
       CASE WHEN ISNULL(Actividad.proactive, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END proactive ,  
       ( SELECT TOP 1  
          Institucion.nombre  
         FROM  ClienteEstudioInstitucion  
          INNER JOIN Institucion ON Institucion.id_institucion = ClienteEstudioInstitucion.id_institucion  
         WHERE     ClienteEstudioInstitucion.id_cliente = Cliente.id_cliente  
          AND ClienteEstudioInstitucion.borrado = 0  
         ORDER BY  ClienteEstudioInstitucion.id_cli_est_institucion DESC  
       ) 'Institución' ,  
       Proyecto.nombre_proyecto 'Proyecto' ,  
       ISNULL(Actividad.fecha_cita, '') 'Fecha Cita' ,  
       ISNULL(Cliente.referencia, '') 'Referencia' ,  
       isnull(( SELECT TOP 1  
           CASE WHEN @id_unidad_negocio = 2  
             THEN C.prioridad_ucal  
             ELSE C.prioridad_tls  
           END  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Prioridad Colegio ' ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_ucal  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') 'Código Colegio Ucal' ,  
       YEAR(Actividad.fecha) 'Año' ,  
       CASE WHEN MONTH(Actividad.fecha) = 1 THEN 'Enero'  
         WHEN MONTH(Actividad.fecha) = 2 THEN 'Febrero'  
         WHEN MONTH(Actividad.fecha) = 3 THEN 'Marzo'  
         WHEN MONTH(Actividad.fecha) = 4 THEN 'Abril'  
         WHEN MONTH(Actividad.fecha) = 5 THEN 'Mayo'  
         WHEN MONTH(Actividad.fecha) = 6 THEN 'Junio'  
         WHEN MONTH(Actividad.fecha) = 7 THEN 'Julio'  
         WHEN MONTH(Actividad.fecha) = 8 THEN 'Agosto'  
         WHEN MONTH(Actividad.fecha) = 9 THEN 'Septiembre'  
         WHEN MONTH(Actividad.fecha) = 10 THEN 'Octubre'  
         WHEN MONTH(Actividad.fecha) = 11 THEN 'Noviembre'  
         WHEN MONTH(Actividad.fecha) = 12 THEN 'Diciembre'  
       END 'Mes' ,  
       CASE WHEN ISNULL(( SELECT TOP 1  
              CE.anio_fin  
              FROM     ClienteEstudioColegio CE  
              WHERE    CE.id_cliente = Actividad.id_cliente  
              AND CE.borrado = 0  
              AND CE.id_unidad_negocio = @id_unidad_negocio  
              ORDER BY CE.id_cli_est_colegio DESC  
           ), 0) = 0 THEN '5'  
         ELSE ( CASE WHEN ISNULL(( SELECT TOP 1  
                 CE.anio_fin  
                 FROM     ClienteEstudioColegio CE  
                 WHERE    CE.id_cliente = Actividad.id_cliente  
                 AND CE.borrado = 0  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
                 ORDER BY CE.id_cli_est_colegio DESC  
               ), 0) < YEAR(Actividad.fecha)  
            THEN 'Egresado'  
            ELSE STR(5  
               - ( ( SELECT TOP 1  
                 CE.anio_fin  
               FROM    ClienteEstudioColegio CE  
               WHERE   CE.id_cliente = Actividad.id_cliente  
                 AND CE.borrado = 0  
                 AND CE.id_unidad_negocio = @id_unidad_negocio  
               ORDER BY CE.id_cli_est_colegio DESC  
                ) - YEAR(Actividad.fecha) ))  
          END )  
       END ,  
       ( SELECT    CONTACTENOS_WEB.observacion_ventas  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Origen' ,  
       ( SELECT    CONTACTENOS_WEB.fecha  
         FROM      CONTACTENOS_WEB  
         WHERE     CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
       ) 'Ingreso de Web' ,  
       ( SELECT TOP 1  
          CAST (CONVERT(NVARCHAR, X.fecha, 103) + ' '  
          + CONVERT(NVARCHAR(5), X.fecha, 108) AS SMALLDATETIME)  --X.fecha                      
         FROM      ( SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Fecha Primera. Acción' ,  
       ( SELECT TOP 1  
          X.tipo_atencion  
         FROM      ( SELECT    A.* ,  
             T.tipo_atencion  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.* ,  
             T.tipo_atencion  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN TipoAtencion T ON A.id_tipo_atencion = T.id_tipo_atencion  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera . Acción' ,  
       ( SELECT TOP 1  
          X.respuesta  
         FROM      ( SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      Actividad A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
            UNION  
            SELECT    A.fecha ,  
             R.respuesta ,  
             A.tipo_tabla  
            FROM      ActividadHistoricaSisproven A WITH ( NOLOCK )  
             INNER JOIN Respuesta_1_N R ON A.id_respuesta_1n = R.id_respuesta_1n  
             INNER JOIN Area B ON A.id_area = B.id_area  
            WHERE     A.id_cliente = Cliente.id_cliente  
             AND B.id_agrupador = @agrupador  
          ) X  
         ORDER BY  X.fecha ASC ,  
          X.tipo_tabla ASC  
       ) AS 'Primera. Respuesta',  
       CASE WHEN Actividad.id_respuesta_1n IN ( 38, 61 )  
         THEN ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              WHERE    UR.id_usuario = Actividad.id_usuario_venta  
            ), '')  
         ELSE ISNULL(( SELECT TOP 1  
              UR.usuario  
              FROM     Usuario UR  
              INNER JOIN ClienteAsesorID ON UR.id_usuario = ClienteAsesorID.id_usuario  
                   AND ClienteAsesorID.id_cliente = Cliente.id_cliente  
                   AND ClienteAsesorID.id_agrupador = Area.id_agrupador  
            ), '')  
       END AS Usuario ,  
       ISNULL(( SELECT TOP 1  
           C.codigo_modular  
          FROM   ClienteEstudioColegio CE ,  
           Colegio C  
          WHERE  CE.id_colegio = C.id_colegio  
           AND CE.id_cliente = Actividad.id_cliente  
           AND CE.borrado = 0  
           AND CE.id_unidad_negocio = @id_unidad_negocio  
          ORDER BY CE.id_cli_est_colegio DESC  
           ), '') codigo_modular ,  
       ( SELECT    motivo_devolucion  
         FROM      MotivoDevolucionExtension  
         WHERE     MotivoDevolucionExtension.id_mot_devolucion = Actividad.id_motivo_anulado  
       ) 'Motivo Anulación Venta DEC' ,  
       ISNULL(Actividad.PromesaPago, '') 'PromesaPago' ,  
       CASE WHEN ISNULL(Actividad.Virtual, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Virtual' ,  
       CASE WHEN ISNULL(Actividad.Presencial, 0) = 1 THEN 'SI'  
         ELSE 'NO'  
       END 'Presencial' ,  
       ISNULL(( SELECT pe.sesion  
          FROM   Programacion_Extension pe  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Sesion' ,  
       ISNULL(( SELECT a.area  
          FROM   Area a  
           INNER JOIN Programacion_Extension pe ON a.id_area = pe.id_area  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Linea_Sesion' ,  
       ISNULL(( SELECT p.programa  
          FROM   Programa p  
           INNER JOIN Programacion_Extension pe ON p.id_programa = pe.id_programa  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Programa_Sesion' ,  
       ISNULL(( SELECT c.curso  
          FROM   Curso c  
           INNER JOIN Programacion_Extension pe ON c.id_curso = pe.id_curso  
          WHERE  pe.id_prog_ext = Actividad.id_prog_ext  
           ), '') 'Curso_Sesion' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_campaign  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_campaign' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_content  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_content' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_medium  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_medium' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_source  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
        )  
         ELSE ''  
       END 'utm_source' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.utm_term  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'utm_term' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.fbclid  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'fbclid' ,  
       CASE WHEN ISNULL(Actividad.id_contacto_web, 0) <> 0  
         THEN ( SELECT  CONTACTENOS_WEB.src  
          FROM    CONTACTENOS_WEB  
          WHERE   CONTACTENOS_WEB.id_contacto_web = Actividad.id_contacto_web  
           )  
         ELSE ''  
       END 'src' ,  
       ( SELECT    Empresa.empresa  
         FROM      ControlDescuento_EC  
          INNER JOIN Empresa ON Empresa.id_empresa = ControlDescuento_EC.id_empresa  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Empresa' ,  
       ( SELECT    ControlDescuento_EC.descripcion  
         FROM      ControlDescuento_EC  
         WHERE     ControlDescuento_EC.id_control_descuento = Actividad.id_control_descuento  
       ) 'Convenio Descripción' ,  
       ISNULL(( SELECT codigo_accion_digital  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'Cod. Acción Digital',  
         ISNULL(( SELECT id_chat  
          FROM   ActividadDigitalData  
          WHERE  ActividadDigitalData.id_actividad = Actividad.id_actividad_historica  
           ), '') 'IdChat'  
                  ,isnull(tb_oportunidad_x_campania.estado,'')as 'Estado Oportunidad'  
           ,isnull(tb_oportunidad_x_campania.fecha,'') as 'Fecha Oportunidad'  
            ,isnull(sedeoportunidad.sede,'') as 'Sede Oportunidad'  
           ,isnull(programaOportunidad.programa,'') as 'Programa Oportunidad'  
             ,isnull(usuOportunidad.usuario,'') as 'Asesor Oportunidad'  
          ,isnull(comentario,'') as 'comentario'  
  
  
 --,isnull((select top 1 Estado from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc ),'') as 'Estado Oportunidad'  
 --         ,isnull((select top 1 fecha from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Fecha Oportunidad'  
 --         ,isnull((select top 1 p.programa  from tb_oportunidad_x_campania c inner join Programa p on c.idprograma=p.id_programa  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Programa Oportunidad'  
 --         ,isnull((select top 1 u.usuario from tb_oportunidad_x_campania c inner join Usuario u on c.idUsuario=u.id_usuario  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Asesor Oportunidad'  
 --         ,isnull((select top 1 s.sede from tb_oportunidad_x_campania c inner join Sede s on c.idSede=s.id_sede  
 --         where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Sede Oportunidad'  
 --         ,isnull((select top 1 comentario from tb_oportunidad_x_campania c where c.idcampania=Campania.id_campania and c.idcliente=Cliente.id_cliente order by c.fecha desc),'') as 'Comentario Oportunidad'  
         
     FROM    ActividadHistoricaSisproven Actividad WITH ( NOLOCK )  
       INNER JOIN Cliente ON Actividad.id_cliente = Cliente.id_cliente  
       LEFT JOIN Distrito ON Cliente.id_distrito = Distrito.id_distrito --, --, , , --, Curso  
       INNER JOIN TipoAtencion ON Actividad.id_tipo_atencion = TipoAtencion.id_tipo_atencion  
       LEFT JOIN Respuesta_1_N ON Actividad.id_respuesta_1n = Respuesta_1_N.id_respuesta_1n  
       LEFT JOIN Respuesta_2_N ON Actividad.id_respuesta_2n = Respuesta_2_N.id_respuesta_2_N  
       LEFT JOIN Area ON Actividad.id_area = Area.id_area  
       LEFT JOIN Programa ON Actividad.id_programa = Programa.id_programa  
       LEFT JOIN Curso ON Actividad.id_curso = Curso.id_curso  
       INNER JOIN Campania ON Actividad.id_campania = Campania.id_campania  
       LEFT JOIN Usuario ON Actividad.id_usuario = Usuario.id_usuario  
       LEFT JOIN Profesion ON Cliente.id_profesion = Profesion.id_profesion  
       LEFT JOIN EstadoCivil ON Cliente.id_estado_civil = EstadoCivil.id_estado_civil  
       LEFT JOIN Nacionalidad ON Cliente.id_nacionalidad = Nacionalidad.id_nacionalidad  
       INNER JOIN UnidadNegocio ON Campania.id_unidad_negocio = UnidadNegocio.id_unidad_negocio  
         
 left join tb_oportunidad_x_campania on tb_oportunidad_x_campania.idcliente=cliente.id_cliente and Campania.id_campania=tb_oportunidad_x_campania.idcampania  
       left join Sede sedeoportunidad on tb_oportunidad_x_campania.idSede=sedeoportunidad.id_sede  
       left join  usuario usuOportunidad on tb_oportunidad_x_campania.idUsuario=usuOportunidad.id_usuario  
       left join Programa programaOportunidad on tb_oportunidad_x_campania.idprograma=programaOportunidad.id_programa  
       LEFT JOIN Sede ON Sede.id_sede = Actividad.id_sede_interes  
       LEFT JOIN Proyecto ON Actividad.id_proyecto = Proyecto.id_proyecto  
     WHERE   Actividad.id_actividad_historica IN ( SELECT  
                   id_actividad  
                  FROM  
                   #datos  
                  WHERE  
                   tipo_tabla = 2 )  
       AND ( @id_unidad_negocio = 0  
          OR Area.id_unidad_negocio = @id_unidad_negocio  
        )  
       AND ( @id_evento = 0  
          OR Actividad.id_evento = @id_evento  
        )  
       AND ( @id_proyecto = 0  
          OR ISNULL(Actividad.id_proyecto, 0) = @id_proyecto  
        ) 
		AND ( @Oportunidad = '' OR tb_oportunidad_x_campania.estado in (SELECT * FROM @TablaOportunidad) )
    END  
  END  
  
    DROP TABLE #datos   