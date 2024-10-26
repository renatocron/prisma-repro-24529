#!/usr/bin/perl
use strict;
use warnings;

# Store the input file content
my $content = '';
{
    local $/;
    $content = <>;
}

# Track relations to remove from the Pessoa model
my %pessoa_relations_to_remove;

# Track all modifications for logging
my @modifications;

# First pass: split content into blocks (enums, models, views) maintaining order
my @blocks;
my %models;
while ($content =~ m{
    (
        (?:enum\s+\w+\s*\{[^\}]+\}) |
        (?:model\s+(\w+)\s*\{[^\}]+\}) |
        (?:view\s+\w+\s*\{[^\}]+\})
    )
}gsx) {
    my $full_block = $1;
    my $model_name = $2;
    push @blocks, $full_block;

    if ($model_name) {
        if ($full_block =~ /model\s+$model_name\s*\{([^\}]+)\}/s) {
            $models{$model_name} = $1;
        }
    }
}

print STDERR "DEBUG: Found " . scalar(keys %models) . " models\n";

# Process each model once
foreach my $model_name (keys %models) {
    next if $model_name eq 'Pessoa';
    print STDERR "DEBUG: Processing model $model_name\n";

    my $model_content = $models{$model_name};

    my @fields = (
        {
            fk_field => 'criado_por',
            relation_name => 'Criador'
        },
        {
            fk_field => 'removido_por',
            relation_name => 'Removedor'
        },
        {
            fk_field => 'atualizado_por',
            relation_name => 'Atualizador'
        }
    );

    foreach my $field (@fields) {
        my $relation_regex = qr/(\w+)\s+Pessoa(\?)?\s+\@relation\("$field->{relation_name}",\s*fields:\s*\[$field->{fk_field}\],\s*references:\s*\[id\]\)/;
        print STDERR "DEBUG: Looking for relation in $model_name for $field->{relation_name}\n";

        if ($model_content =~ $relation_regex) {
            my $relation_field = $1;
            print STDERR "DEBUG: Found relation field: $relation_field\n";

            # Remove the relation line from the model, preserving newlines
            my $removed = $model_content =~ s/(\s*)$relation_field\s+Pessoa(\?)?\s+\@relation\("$field->{relation_name}",\s*fields:\s*\[$field->{fk_field}\],\s*references:\s*\[id\]\)\s*\n/$1/g;

            if ($removed) {
                print STDERR "DEBUG: Removed relation $relation_field\n";

                # Find matching reverse relation in Pessoa model
                if ($models{Pessoa} =~ /(\w+)\s+$model_name\[\]\s+\@relation\("$field->{relation_name}"\)/) {
                    my $reverse_field = $1;
                    print STDERR "DEBUG: Found reverse relation field: $reverse_field\n";

                    $pessoa_relations_to_remove{$reverse_field} = {
                        model => $model_name,
                        relation_name => $field->{relation_name}
                    };

                    # Log the modification
                    push @modifications, {
                        table => $model_name,
                        removed_field => $relation_field,
                        relation_name => $field->{relation_name},
                        fk_field => $field->{fk_field},
                        reverse_field => $reverse_field
                    };
                    print STDERR "DEBUG: Added modification log entry for $model_name.$relation_field\n";
                } else {
                    print STDERR "DEBUG: No reverse relation found for $model_name.$relation_field\n";
                }
            }
        }
    }

    # Update the model content in our hash
    $models{$model_name} = $model_content;
}

# Clean up the Pessoa model
print STDERR "DEBUG: Cleaning up Pessoa model relations\n";
foreach my $rel (keys %pessoa_relations_to_remove) {
    my $model = $pessoa_relations_to_remove{$rel}->{model};
    # Remove relation line while preserving line breaks
    $models{Pessoa} =~ s/(\s*)$rel\s+$model\[\]\s+\@relation\("$pessoa_relations_to_remove{$rel}->{relation_name}"\)\s*\n/$1/g;
    print STDERR "DEBUG: Removed reverse relation $rel from Pessoa model\n";
}

# Reconstruct the content while preserving all blocks
$content =~ s/(generator.*?\}.*?datasource.*?\})//s;
my $header = $1;
my $new_content = $header . "\n";

foreach my $block (@blocks) {
    if ($block =~ /model\s+(\w+)\s*\{/s) {
        my $model_name = $1;
        if (exists $models{$model_name}) {
            $new_content .= "\nmodel $model_name {\n$models{$model_name}}\n";
        }
    } else {
        # Keep enum and view blocks unchanged
        $new_content .= "\n$block\n";
    }
}

# Output the modified schema
print $new_content;

# Output the log
print STDERR "\n=== Modification Log ===\n";
foreach my $mod (@modifications) {
    print STDERR "Table: $mod->{table}\n";
    print STDERR "  Removed field: $mod->{removed_field}\n";
    print STDERR "  Removed relation: $mod->{relation_name}\n";
    print STDERR "  Kept FK field: $mod->{fk_field}\n";
    print STDERR "  Removed reverse relation from Pessoa model: $mod->{reverse_field}\n";
    print STDERR "\n";
}
