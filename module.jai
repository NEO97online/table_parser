/*
The T2D file format represents a 2D array.

The first line is the header. It defines the order and names of fields.
*/

TableParserResult :: struct ($row_type: Type) {
    data: [..][..] row_type;
    success: bool;
    error_line: int;
    error_char: int;
    error_message: string;
}

load_tbl_string :: (str: string, $row_type: Type, $key_type: Type = int) -> TableParserResult(row_type) {
    row_info :: type_info(row_type);
    key_info :: type_info(key_type);
    #assert row_info.type == .STRUCT "row_type must be a Struct.";
    #assert key_info.type == .ENUM || key_info.type == .INTEGER "key_type must be an Enum or Integer.";

    result: TableParserResult(row_type);
    #if key_info.type == .ENUM {
        array_resize(*result.data, enum_highest_value(key_type) + 1);        
    }

    line := 0;
    index_in_line := 0;
    c := 0;
    char := str[c];
    current_key := -1;
    current_row := 0;
    current_row_data: row_type;
    current_row_columns: [..] string;

    fields: [..] string;
    fields.allocator = temp;

    State :: enum {
        ROW;
        KEY;
        STRING;
    }
    state := State.ROW;

    sb: String_Builder;
    sb.allocator = temp;

    // read fields from header
    while line == 0 {
        char = str[c];
        if char == {
            case #char " "; #through;
            case #char "\t";
                field := builder_to_string(*sb);
                if field.count > 0 array_add(*fields, field);
            case #char "\n";
                field := builder_to_string(*sb);
                if field.count > 0 array_add(*fields, field);
                line += 1;
                // now we know the fields... do something?
            case;
                print(*sb, "%", to_string(*char, 1));
        }
        c += 1;
    }

    print("fields: %\n", fields);
    field_infos: [..] Type_Info_Struct_Member;
    for field : fields {
        found_field := false;
        for member : row_info.members {
            if member.name == field {
                array_add(*field_infos, member);
                found_field = true;
                break;
            }
        }
        if !found_field {
            result.error_line = line;
            result.error_char = c;
            result.error_message = tprint("Invalid field: % is not in struct %", field, row_info.name);
            return result;
        }
    }
    print("field_infos: %\n", field_infos);

    // from here we start at line 1, header is already parsed
    while c < str.count {
        char = str[c];
        print("char: %\n", to_string(*char, 1));
        if state == {
            case .ROW;
                if index_in_line == 0 && char == #char "=" {
                    // lines starting with at least one `=` are new keys.
                    state = .KEY;
                } else if char == #char "\n" {
                    column := builder_to_string(*sb);
                    if column.count > 0 {
                        array_add(*current_row_columns, column);
                    }
                    line += 1;
                    index_in_line = 0;
                    print("%\n", current_row_columns);
                    if fields.count != current_row_columns.count {
                        result.error_line = line;
                        result.error_char = c;
                        result.error_message = tprint("Incorrect number of columns in this row. Expected %, got %", fields.count, current_row_columns.count);
                        return result;
                    }
                    row: row_type;
                    for field_info : field_infos {
                        column_string := current_row_columns[it_index];
                        column_ptr := (cast(*void) *row) + field_info.offset_in_bytes;
                        if field_info.type.type == {
                            case .INTEGER;
                                (cast(*int) column_ptr).* = string_to_int(column_string);
                            case .FLOAT;
                                (cast(*float) column_ptr).* = string_to_float(column_string);
                            case .ENUM;
                                enum_info := cast(*Type_Info_Enum) field_info.type;
                                value := -1;
                                print("names: %\n", enum_info.name);
                                for enum_info.names if it == column_string then value = enum_info.values[it_index];
                                if value < 0 {
                                    result.error_line = line;
                                    result.error_char = c;
                                    result.error_message = tprint("Invalid enum variant in row %, column %: %", current_row, it_index, column_string);
                                    return result;
                                }
                                (cast(*int) column_ptr).* = value;
                            case .STRING;
                                // we copy the string to the heap since column_string is from the temp allocator
                                column_string_copy := alloc_string(column_string.count);
                                memcpy(column_string_copy.data, column_string.data, column_string.count);
                                (cast(*string) column_ptr).* = column_string_copy;
                            case;
                                result.error_line = line;
                                result.error_char = c;
                                result.error_message = tprint("Unsupported field type: %", field_info.type.type);
                                return result;
                        }
                    }
                    array_add(*result.data[current_key], row);
                    array_reset_keeping_memory(*current_row_columns);
                } else if char == #char " " {
                    column := builder_to_string(*sb);
                    if column.count > 0 {
                        array_add(*current_row_columns, column);
                    }
                } else if char == #char "\"" {
                    state = .STRING;
                } else {
                    print(*sb, to_string(*char, 1));
                }
            case .KEY;
                if char == #char "=" || char == #char " " || char == #char "\t" {
                    // user can type as many `===== == ==     ` as they want...
                } else if char == #char "\n" {
                    key := builder_to_string(*sb);
                    if key.count > 0 {
                        #if key_info.type == .ENUM {
                            value: int = -1;
                            for enum_names(key_type) {
                                if it == key {
                                    value = enum_values_as_s64(key_type)[it_index];
                                    break;
                                }
                            }
                            if value == -1 {
                                result.error_line = line;
                                result.error_char = c;
                                result.error_message = tprint("Invalid key: % is not in key enum: %", key, key_type);
                                return result;
                            }
                            current_key = value;
                            current_row = 0;
                            state = .ROW;
                            line += 1;
                            index_in_line = 0;
                        } else {
                            result.error_line = line;
                            result.error_char = c;
                            result.error_message = "Found a key name, but no key_type Enum was given.";
                            return result;
                        }
                    } else {
                        // no key specified, we'll just increment current_key
                        current_key += 1;
                        current_row = 0;
                        state = .ROW;
                        line += 1;
                        index_in_line = 0;
                        #if key_info.type == .INTEGER {
                            if current_key > result.data.count-1 {
                                array_resize(*result.data, current_key+1);
                            }
                        }
                    }
                } else {
                    print(*sb, to_string(*char, 1));
                }
            case .STRING;
                if char == #char "\"" {
                    column := builder_to_string(*sb);
                    array_add(*current_row_columns, column);
                    state = .ROW;
                } else {
                    print(*sb, to_string(*char, 1));
                }
        }
        c += 1;
    }

    result.success = true;

    return result;
}

#scope_module

#import "Basic";
#import "File";
#import "String";