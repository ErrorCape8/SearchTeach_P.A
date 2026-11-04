package com.pa.searchteach.users.model;

public record MateriaPrincipalDocente(String materia, String tecnologia) {

    public MateriaPrincipalDocente {
        if (materia == null || materia.isBlank() || tecnologia == null || tecnologia.isBlank()) {
            throw new IllegalArgumentException("La materia principal debe tener materia y tecnología válidas.");
        }
        materia = materia.trim();
        tecnologia = tecnologia.trim();
    }

    public boolean aplica(String tecnologia, int semestre, String materia) {
        return this.tecnologia.equalsIgnoreCase(tecnologia)
                && this.materia.equalsIgnoreCase(materia);
    }
}
