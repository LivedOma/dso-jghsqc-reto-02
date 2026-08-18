package com.curso.demo;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class HolaController {

    /**
     * La version se inyecta como variable de entorno (APP_VERSION).
     * Asi el mismo binario sirve para cualquier ambiente: nada quemado en el codigo.
     */
    @Value("${app.version:local}")
    private String version;

    @GetMapping("/")
    public Map<String, String> hola(@RequestParam(defaultValue = "mundo") String nombre) {
        Map<String, String> respuesta = new LinkedHashMap<>();
        respuesta.put("mensaje", "Hola " + nombre + " desde el microservicio");
        respuesta.put("version", version);
        respuesta.put("timestamp", Instant.now().toString());
        return respuesta;
    }

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("version", version);
    }
}
