package com.curso.demo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class HolaControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void saludoPorDefectoRespondeOk() throws Exception {
        mockMvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mensaje").value("Hola mundo desde el microservicio"));
    }

    @Test
    void saludoConNombreUsaElParametro() throws Exception {
        mockMvc.perform(get("/").param("nombre", "DevSecOps"))
                .andExpect(jsonPath("$.mensaje").value("Hola DevSecOps desde el microservicio"));
    }

    @Test
    void endpointVersionRespondeOk() throws Exception {
        mockMvc.perform(get("/version"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").exists());
    }
}
