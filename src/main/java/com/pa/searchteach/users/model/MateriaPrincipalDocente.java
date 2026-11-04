package com.pa.searchteach.users.model;

import java.util.List;

public record MateriaPrincipalDocente(
        String materia,
        String tecnologia,
        List<Integer> semestres) {

    public MateriaPrincipalDocente {
        if (materia == null || materia.isBlank()
                || tecnologia == null || tecnologia.isBlank()
                || semestres == null || semestres.isEmpty()
                || semestres.stream().anyMatch(semestre -> semestre == null || semestre < 1 || semestre > 6)) {
            throw new IllegalArgumentException("La materia principal debe tener tecnología y semestres válidos.");
        }
        materia = materia.trim();
        tecnologia = tecnologia.trim();
        semestres = semestres.stream().distinct().sorted().toList();
    }

    public boolean aplica(String tecnologia, int semestre, String materia) {
        return this.tecnologia.equalsIgnoreCase(tecnologia)
                && semestres.contains(semestre)
                && this.materia.equalsIgnoreCase(materia);
    }
}
