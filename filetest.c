#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void write_file(const char *filename) {
    FILE *file = fopen(filename, "w"); // สร้างไฟล์ หรือ ทับไฟล์เดิม
    if (file == NULL) {
        return;
    }

    char content[1024];
    printf("Enter text to write %s:",filename);

    if (fgets(content,sizeof(content),stdin) != NULL) {
        content[strcspn(content, "\n")] = 0;
        fprintf(file, "%s\n", content);
    } else {
        return;
    }

    fclose(file);
}

void edit_file(const char *filename) {
    FILE *file = fopen(filename, "a"); // แก้ไขไฟล์

    if (file == NULL) {
        return;
    }

    char content[1024];
    printf("Enter text to append to %s:",filename);

    if (fgets(content,sizeof(content),stdin) != NULL) {
        content[strcspn(content, "\n")] = 0;
        fprintf(file, "%s\n", content);
    } else {
        return;
    }

    fclose(file);
}

void read_file(const char *filename) {
    FILE *file = fopen(filename, "r"); // อ่านไฟล์
    if (file == NULL) {
        return;
    }

    char content[1024];
    while (fgets(content,sizeof(content),file) != NULL) {
        printf("%s",content);
    }

    fclose(file);
}

void delete_file(const char *filename) {
    if (remove(filename) == 0) {
        printf("File %s deleted successfully\n",filename);
    } else {
        printf("Error deleting file %s\n",filename);
    }
}

int main() {
    int choice;
    char filename[100];

    do {
        printf("\n1. Write file\n");
        printf("2. Edit file\n");
        printf("3. Read file\n");
        printf("4. Delete file\n");
        printf("5. Exit\n");
        printf("Enter your choice: ");
        scanf("%d",&choice);

        switch (choice) {
            case 1:
                printf("Enter filename: ");
                scanf("%s",filename);
                write_file(filename);
                break;
            case 2:
                printf("Enter filename: ");
                scanf("%s",filename);
                edit_file(filename);
                break;
            case 3:
                printf("Enter filename: ");
                scanf("%s",filename);
                read_file(filename);
                break;
            case 4:
                printf("Enter filename: ");
                scanf("%s",filename);
                delete_file(filename);
                break;
            case 5:
                printf("Exiting...\n");
                break;
            default:
                printf("Invalid choice\n");
        }
    } while (choice != 5);

    return 0;
}
